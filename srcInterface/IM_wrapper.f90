! Wrapper for Internal Magnetosphere (IM) component
!=============================================================================

subroutine IM_set_param(CompInfo,TypeAction)

  use CON_comp_info
  use ModProcIM
  use ModHeidiMain
  use ModReadParam, ONLY: i_session_read
  use ModUtilities, ONLY: fix_dir_name, check_dir, lower_case
  use ModHeidiIO,   ONLY: IsFramework, StringPrefix
  use ModIoUnit,    ONLY: STDOUT_

  implicit none
  character (len=*), parameter :: NameSub='IM_set_param'

  ! Arguments
  type(CompInfoType), intent(inout) :: CompInfo   ! Information for this comp.
  character (len=*), intent(in)     :: TypeAction ! What to do

  !LOCAL VARIABLES:
  character (len=100) :: NameCommand, StringPlot
  logical             :: DoEcho=.false.
  logical             :: UseStrict=.true.  
  integer             :: iUnitOut
  !---------------------------------------------------------------------------
  select case(TypeAction)

  case('VERSION')
     call put(CompInfo,                         &
          Use=.true.,                           &
          NameVersion='RAM_HEIDI (Liemohn)',    &
          Version=1.1)

  case('MPI')
     call get(CompInfo, iComm=iComm, iProc=iProc, nProc=nProc)
     if(nProc>4)call CON_stop( NameSub // &
          ' IM_ERROR this version can run on 4 PE !')
     IsFramework = .true.

  case('CHECK')
     !We should check and correct parameters here
     if(iProc==0)write(*,*) NameSub,': CHECK iSession =',i_session_read()
     call heidi_check

  case('GRID')
     call IM_set_grid  

  case('READ')
     call heidi_read

  case('STDOUT')
     iUnitOut = STDOUT_
     if(nProc==1)then
        StringPrefix='IM:'
     else
        write(StringPrefix,'(a,i3.3,a)')'IM',iProc,':'
     end if

  case('FILEOUT')
     call get(CompInfo,iUnitOut=iUnitOut)
     StringPrefix=''

  case default
     call CON_stop(NameSub//' IM_ERROR: invalid TypeAction='//TypeAction)

  end select

end subroutine IM_set_param

!============================================================================

subroutine IM_set_grid

  use ModNumConst,  ONLY: cTwoPi
  use CON_coupler,  ONLY: set_grid_descriptor, is_proc, IM_
  use ModHeidiSize, ONLY: RadiusMin, RadiusMax,NT,NR
  use ModHeidiMain, ONLY: LZ, DL1, DPHI,PHI

  implicit none

  character (len=*), parameter :: NameSub='IM_set_grid'
  logical :: IsInitialized=.false.
  logical :: DoTest, DoTestMe
  integer :: i, j  
  !-------------------------------------------------------------------------

  call CON_set_do_test(NameSub, DoTest, DoTestMe)
  if(DoTest)write(*,*)'IM_set_grid called, IsInitialized=', &
       IsInitialized
  if(IsInitialized) return

  IsInitialized = .true.

  ! IM grid: the equatorial grid is described by Coord1_I and Coord2_I
  ! Occasional +0.0 is used to convert from single to double precision

  call set_grid_descriptor( IM_,           & ! component index
       nDim     = 2,                       & ! dimensionality
       nRootBlock_D = (/1,1/),             & ! number of blocks
       nCell_D =(/nR, nT-1/),              & ! size of equatorial grid
       XyzMin_D=(/RadiusMin+0.0,0.0/),     & ! min coordinates
       XyzMax_D=(/RadiusMax+0.0,cTwoPi/),  & ! max coordinates
       Coord1_I = LZ(1:nR)+0.0,            & ! radial coordinates
       Coord2_I = Phi(1:nT-1)+0.0,         & ! longitudinal coordinates
       TypeCoord= 'SMG' )                    ! solar magnetic coord

  if(DoTest)then
     write(*,*)NameSub,' NR = ', NR
     write(*,*)NameSub,' NT = ', NT
  end if


end subroutine IM_set_grid
!==============================================================================
subroutine IM_get_for_ie(nPoint,iPointStart,Index,Weight,Buff_V,nVar)

  ! Provide current for IE
  ! The value should be interpolated from nPoints with
  ! indexes stored in Index and weights stored in Weight
  ! The variables should be put into Buff_V(??)

  use CON_router,   ONLY: IndexPtrType, WeightPtrType
  use ModIonoHeidi, ONLY: IONO_NORTH_RCM_JR,IONO_SOUTH_RCM_JR, IONO_nTheta, IONO_nPsi

  implicit none
  character(len=*), parameter :: NameSub='IM_get_for_ie'

  integer,intent(in)            :: nPoint, iPointStart, nVar
  real,intent(out)              :: Buff_V(nVar)
  type(IndexPtrType),intent(in) :: Index
  type(WeightPtrType),intent(in):: Weight

  integer :: iLat, iLon, iBlock, iPoint
  real    :: w

  !---------------------------------------------------------------------------
  Buff_V = 0.0

  do iPoint = iPointStart, iPointStart + nPoint - 1

     iLat   = Index % iCB_II(1,iPoint)
     iLon   = Index % iCB_II(2,iPoint)
     iBlock = Index % iCB_II(3,iPoint)
     w      = Weight % Weight_I(iPoint)

     if(iBlock/=1)then
        write(*,*)NameSub,': iPoint,Index % iCB_II=',&
             iPoint,Index%iCB_II(:,iPoint)
        call CON_stop(NameSub//&
             ' SWMF_ERROR iBlock should be 1=North in IM-IE coupling')
     end if

     if(iLat<1 .or. iLat>IONO_nTheta*2 .or. iLon<1 .or. iLon>IONO_nPsi+1)then
        write(*,*)'iLat,iLon=',iLat, IONO_nTheta*2, iLon, IONO_nPsi
        call CON_stop(NameSub//' SWMF_ERROR index out of range')
     end if

     ! Only worry about the northern hemisphere....  IE can fix the southern hemisphere.
     if (iLat <= IONO_nTheta .and. iLon <= IONO_nPsi) &
          Buff_V(1) = Buff_V(1) + w * IONO_NORTH_RCM_JR(iLat,iLon)

     if (iLat > IONO_nTheta .and. iLon <= IONO_nPsi) &
          Buff_V(1) = Buff_V(1) + w * IONO_SOUTH_RCM_JR(2*IONO_nTheta-iLat+1,iLon)

  end do

end subroutine IM_get_for_ie

!============================================================================
subroutine IM_put_from_ie_mpi(nTheta, nPhi, Potential_II)

  use ModHeidiIO,  ONLY: time
  use ModPlotFile, ONLY: save_plot_file

  implicit none

  integer, intent(in):: nTheta, nPhi
  real,    intent(in):: Potential_II(nTheta, nPhi, 1)

  character(len=100):: NameFile
  !-------------------------------------------------------------------------
  write(NameFile,'(a,i5.5,a)') &
       "IM/plots/potential_t",nint(Time),".out"

  call save_plot_file(NameFile, &
       StringHeaderIn = 'Ionospheric potential', &
       TimeIn         = time+0.0, &
       NameVarIn      = 'Theta Phi Pot', &
       CoordMinIn_D   = (/0.0, 0.0/), &
       CoordMaxIn_D   = (/180.0,360.0/), &
       VarIn_IIV = Potential_II)

end subroutine IM_put_from_ie_mpi

!==============================================================================
subroutine IM_put_from_ie(nPoint,iPointStart,Index,Weight,DoAdd,Buff_V,nVar)

  use CON_router,   ONLY: IndexPtrType, WeightPtrType
  use ModIonoHeidi, ONLY: IONO_NORTH_PHI, IONO_SOUTH_PHI, IONO_nTheta, IONO_nPsi

  implicit none
  character(len=*), parameter   :: NameSub='IM_put_from_ie'
  integer,intent(in)            :: nPoint, iPointStart, nVar
  real, intent(in)              :: Buff_V(nVar)
  type(IndexPtrType),intent(in) :: Index
  type(WeightPtrType),intent(in):: Weight
  logical,intent(in)            :: DoAdd
  integer :: iBlock,i,j
  !---------------------------------------------------------------------------
  if(nPoint>1)then
     write(*,*)NameSub,': nPoint,iPointStart,Weight=',&
          nPoint,iPointStart,Weight % Weight_I
     call CON_stop(NameSub//': should be called with 1 point')
  end if
  if(DoAdd)then
     write(*,*)NameSub,': nPoint,iPointStart,Weight=',&
          nPoint,iPointStart,Weight % Weight_I
     write(*,*)NameSub,': WARNING DoAdd is true'
  end if

  i = Index % iCB_II(1,iPointStart)
  j = Index % iCB_II(2,iPointStart)

  if(i<1.or.i>2*IONO_nTheta-1.or.j<1.or.j>IONO_nPsi+1)then
     write(*,*)'i,j,DoAdd=',i,2*IONO_nTheta-1,j,IONO_nPsi+1,DoAdd
     call CON_stop('IM_put_from_ie (in IM_wrapper): index out of range')
  end if

  if (i <= IONO_nTheta .and. j <= IONO_nPsi) then
     if(DoAdd)then
        IONO_NORTH_PHI(i,j)        = IONO_NORTH_PHI(i,j)        + Buff_V(1)
     else
        IONO_NORTH_PHI(i,j)        = Buff_V(1)
     end if
  endif

  if (i > IONO_nTheta .and. j <= IONO_nPsi) then
     if(DoAdd)then
        IONO_SOUTH_PHI(i-IONO_nTheta,j) = &
             IONO_SOUTH_PHI(i-IONO_nTheta,j) + Buff_V(1)
     else
        IONO_SOUTH_PHI(i-IONO_nTheta,j) = Buff_V(1)
     end if
  endif

end subroutine IM_put_from_ie
!==============================================================================
subroutine IM_put_from_ie_complete

  implicit none

  !--------------------------------------------------------------------------

  write(*,*) "Don't know what this is really supposed to do.  I think that it is"
  write(*,*) "Supposed to be applying periodic boundaries...?"

end subroutine IM_put_from_ie_complete

!==============================================================================

subroutine IM_put_from_gm(Buffer_IIV,iSizeIn,jSizeIn,nVarIn,NameVar)

  ! This should be similar to RBE coupling

  use ModIonoHeidi
  use ModConst

  implicit none

  character (len=*),parameter :: NameSub='IM_put_from_gm'

  integer, intent(in) :: iSizeIn,jSizeIn,nVarIn
  real, dimension(iSizeIn,jSizeIn,nVarIn), intent(in) :: Buffer_IIV
  character (len=*),intent(in)       :: NameVar

  integer, parameter :: vol_=1, z0x_=2, z0y_=3, bmin_=4, rho_=5, p_=6
  logical :: DoTest, DoTestMe
  !---------------------------------------------------------------------------
  call CON_set_do_test(NameSub, DoTest, DoTestMe)

  if(DoTest)write(*,*)NameSub,' starting with NameVar=',NameVar

  IonoGmVolume   = Buffer_IIV(:,:,vol_)
  IonoGmXPoint   = Buffer_IIV(:,:,z0x_)
  IonoGmYPoint   = Buffer_IIV(:,:,z0y_)
  IonoGmBField   = Buffer_IIV(:,:,bmin_)
  ! I think that this is mass density in SI units.  Change to number density
  ! in #/cc.  Then get rid of -1 values.
  IonoGmDensity  = Buffer_IIV(:,:,rho_)/cProtonMass/1.0e6
  where (IonoGmDensity < 0.0) IonoGmDensity = 0.0

  ! This is in Pascals
  IonoGmPressure = Buffer_IIV(:,:,p_)
  where (IonoGmPressure < 0.0) IonoGmPressure = 0.0

  IonoGmTemperature = 0.0
  where (IonoGmDensity > 0) &
       IonoGmTemperature = IonoGmPressure/(IonoGmDensity*1.0e6*cBoltzmann)/&
       11604.0 ! k -> eV

  !  write(*,*) 'This is not working'

end subroutine IM_put_from_gm

!==============================================================================

subroutine IM_put_from_gm_line(nRadiusIn, nLonIn, Map_DSII, &
     nVarLineIn, nPointLineIn, BufferLine_VI, NameVar)

  use ModHeidiMain,   ONLY: nR, nT, LZ, BHeidi_III, SHeidi_III, RHeidi_III,&
       bGradB1xHeidi_III,bGradB1yHeidi_III, bGradB1zHeidi_III,&
       BrHeidi_III, BThetaHeidi_III, BPhiHeidi_III
  use ModHeidiIO,     ONLY: Time
  use ModHeidiSize,   ONLY: RadiusMin, RadiusMax, nPointEq
  use ModIoUnit,      ONLY: UnitTmp_
  use ModPlotFile,    ONLY: save_plot_file
  use ModHeidiBField, ONLY: dipole_length

  implicit none

  integer, intent(in)          :: nRadiusIn, nLonIn
  real,    intent(in)          :: Map_DSII(3,2,nRadiusIn,nLonIn)
  integer, intent(in)          :: nVarLineIn, nPointLineIn
  real,    intent(in)          :: BufferLine_VI(nVarLineIn,nPointLineIn)

  character(len=*), intent(in) :: NameVar
  character(len=*), parameter  :: NameSub='IM_put_from_gm_line'
  character(len=100)           :: NameFile
  logical                      :: IsFirstCall = .true.
  logical                      :: DoTest, DoTestMe

  ! These variables should either be in a module, OR
  ! there is no need for them, and BufferLine_VI should be put 
  ! into HEIDI variables right here. 
  ! Note that this routine is only called on the root processor !!!

  integer :: nVarLine   = 0          ! number of vars per line point
  integer :: nPointLine = 0          ! number of points in all lines
  real, save, allocatable :: StateLine_VI(:,:)   ! state along all lines

  integer, parameter             :: I_=1, S_=2, X_=3, Y_=4, Z_=5
  integer, parameter             :: Bx_=10, By_=11, Bz_=12, gx_=14, gy_=15, gz_=16 
  integer, parameter             :: nStepInside = 10, nStepInterp = 40
  integer, parameter             :: nStep = 2*(nStepInside + nStepInterp)+1
  real,    parameter             :: rBoundary = 2.5
!  real,    parameter             ::DipoleStrength = 0.32 !7.19e15
  real,    parameter             :: DipoleStrength = 7.19e15
  real,    parameter             :: Re = 6357.0e3

  !Local Variables
  real,dimension(nStepInside,nR) :: bDipoleN_II, rDipoleN_II, sDipoleN_II
  real,dimension(nStepInside,nR) :: bDipoleS_II, rDipoleS_II, sDipoleS_II  
  real,dimension(nStepInside,nR) :: BrDipoleN_II, BThetaDipoleN_II, BPhiDipoleN_II
  real,dimension(nStepInside,nR) :: BrDipoleS_II, BThetaDipoleS_II, BPhiDipoleS_II
  real,dimension(nStepInside,nR) :: bGradB1xN_II, bGradB1yN_II, bGradB1xS_II, bGradB1yS_II
  real,dimension(nStep,nR)       :: bDipole_II, rDipole_II, sDipole_II
  real,dimension(nStep,nR)       :: BrDipole_II, BThetaDipole_II, BPhiDipole_II
  real,dimension(nStep,nR)       :: bGradB1x_II, bGradB1y_II
  real, dimension(nStepInterp)   :: LengthHeidi_I,BHeidi_I,RHeidi_I
  real, dimension(nStepInterp)   :: LengthHeidi1_I,BHeidi1_I,RHeidi1_I
  real, dimension(nStepInterp)   :: BxHeidi1_I,ByHeidi1_I,BzHeidi1_I
  real, dimension(nStepInterp)   :: BxHeidi_I,ByHeidi_I,BzHeidi_I
  real, dimension(nStepInterp)   :: bGradB1xHeidi1_I, bGradB1yHeidi1_I, bGradB1zHeidi1_I
  real, dimension(nStepInterp)   :: bGradB1xHeidi_I, bGradB1yHeidi_I, bGradB1zHeidi_I
  integer,save                   :: iRiTiDIr_DI(3,2*nR*nT)                ! line index 
  real, allocatable              :: B_I(:), Length_I(:),RadialDist_I(:)
  real, allocatable              :: bGradB1x_I(:), bGradB1y_I(:), bGradB1z_I(:)
  real, allocatable              :: bGradB1x1_I(:), bGradB1y1_I(:), bGradB1z1_I(:)
  real, allocatable              :: B1_I(:), Length1_I(:),RadialDist1_I(:)
  real, allocatable              :: Bx_I(:), Bx1_I(:), By_I(:), By1_I(:), Bz_I(:),Bz1_I(:)
  real                           :: LatMax, LatMin, Lat, dLat
  real                           :: SinLat2,CosLat2, x
  real                           :: Tr,Ttheta, r,gradB0R1,gradB0R2, gradB0Theta1,gradB0Theta2
  integer                        :: iStep,ns,np
  integer                        :: iR, iT, iDir, n
  integer                        :: iPoint
  integer                        :: iMax, i, iLineLast,iLine,imax1,iLineFirst,j
  !---------------------------------------------------------------------------
  call CON_set_do_test(NameSub, DoTest, DoTestMe)

  ! Save total number of points along all field lines
  nPointLine = nPointLineIn
  nVarLine   = nVarLineIn

  ! Alloocate buffer
  if (allocated(StateLine_VI)) deallocate(StateLine_VI)
  if (.not.allocated(StateLine_VI)) allocate(StateLine_VI(nVarLine,nPointLine))

  ! Copy into local variables
  StateLine_VI = BufferLine_VI

  ! StateLine_VI = PlotVar_V
  if(DoTest)then
     write(*,*)NameSub,' nVarLine,nPointLine=',nVarLine,nPointLine

     ! Set the file name
     write(NameFile,'(a,i5.5,a)') &
          "IM/plots/ray_data_t",nint(Time),".out"
     open(UnitTmp_, FILE=NameFile, STATUS="replace")
     ! Same format as in GM/BATSRUS/src/ray_trace_new.f90
     write(UnitTmp_, *) 'nRadius, nLon, nPoint=',nR, nT, nPointLine
     write(UnitTmp_, *) 'iLine l x y z rho ux uy uz bx by bz p bgradb1x bgradb1y bgradb1z'
     do iPoint = 1, nPointLine
        write(UnitTmp_, *) StateLine_VI(:, iPoint)
     end do
     close(UnitTmp_)

     ! Now save the mapping files (+0.0 for real precision)
     write(NameFile,'(a,i5.5,a)') &
          "IM/plots/map_north_t",nint(Time),".out"

     call save_plot_file( &
          NameFile, &
          StringHeaderIn = 'Mapping to northern ionosphere', &
          TimeIn       = Time+0.0, &
          NameVarIn    = 'r Lon rIono ThetaIono PhiIono', &
          CoordMinIn_D = (/RadiusMin+0.0,   0.0/), &
          CoordMaxIn_D = (/RadiusMax+0.0, 360.0/), &
          VarIn_VII    = Map_DSII(:,1,:,:))

     write(NameFile,'(a,i5.5,a)') &
          "IM/plots/map_south_t",nint(Time),".out"
     call save_plot_file( &
          NameFile, &
          StringHeaderIn = 'Mapping to southern ionosphere', &
          TimeIn       = Time+0.0, &
          NameVarIn    = 'r Lon rIono ThetaIono PhiIono', &
          CoordMinIn_D = (/RadiusMin+0.0,   0.0/), &
          CoordMaxIn_D = (/RadiusMax+0.0, 360.0/), &
          VarIn_VII    = Map_DSII(:,2,:,:))
  end if

  ! Convert Units here. Input is in SI !!!

  ! Check Map_DSII for open-closed field lines, also use it for mapping
  ! to the ionosphere for electric potential.

  !\
  ! Create index array that converts radial and local time index to line index
  !/

  iPoint = 0
  do iT = 1, nT
     do iR = 1, nR
        do iDir = 1, 2
           iPoint =iPoint +1
           iRiTiDir_DI(:,iPoint) = (/iR, iT, iDir/)
        end do
     end do
  end do

  !\
  ! Count the maximum size of the field line array (iMax)
  !/

  iMax = 0 ; iLineLast = -1; i = 1
  do iPoint =1 ,nPointLine
     if (StateLine_VI(1,iPoint) == iLineLast) then
        i = i + 1
        iMax = max(iMax,i)
     else
        i =1
     end if
     iLineLast = StateLine_VI(1,iPoint)
  end do

  allocate(B_I(iMax)); allocate(Length_I(iMax)); allocate(RadialDist_I(iMax))
  allocate(B1_I(iMax)); allocate(Length1_I(iMax)); allocate(RadialDist1_I(iMax))
  allocate(bGradB1x1_I(iMax)); allocate(bGradB1y1_I(iMax)); allocate(bGradB1z1_I(iMax));
  allocate(bGradB1x_I(iMax)); allocate(bGradB1y_I(iMax)); allocate(bGradB1z_I(iMax));
  allocate(Bx_I(iMax)); allocate(By_I(iMax)); allocate(Bz_I(iMax));
  allocate(Bx1_I(iMax)); allocate(By1_I(iMax)); allocate(Bz1_I(iMax));

  iMax1 = 0
  B_I = 0.0
  iLineFirst = StateLine_VI(1,1)
  iLineLast = -1
  i = 1
  j = 1

  BHeidi_I = 0.0; LengthHeidi_I = 0.0; RHeidi_I = 0.0
  bGradB1x_I = 0.0; bGradB1x_I = 0.0; bGradB1z_I = 0.0


  do iPoint = 1, nPointLine
     if  (StateLine_VI(1,iPoint) == iLineFirst)  then
        ! B field in Gauss
!        B1_I(j) = 10000.0*sqrt(StateLine_VI(BX_,iPoint)**2 + &
!             StateLine_VI(BY_,iPoint)**2 + StateLine_VI(BZ_,iPoint)**2)

        ! in nT
        B1_I(j) = sqrt(StateLine_VI(BX_,iPoint)**2 + &
             StateLine_VI(BY_,iPoint)**2 + StateLine_VI(BZ_,iPoint)**2)

        Length1_I (j) = StateLine_VI(S_,iPoint)
        RadialDist1_I(j) = sqrt(StateLine_VI(X_,iPoint)**2 + &
             StateLine_VI(Y_,iPoint)**2 + StateLine_VI(Z_,iPoint)**2 )

        Bx1_I(j) = StateLine_VI(BX_,iPoint)
        By1_I(j) = StateLine_VI(BY_,iPoint)
        Bz1_I(j) = StateLine_VI(BZ_,iPoint)

        bGradB1x1_I(j) = StateLine_VI(gx_,iPoint)
        bGradB1y1_I(j) = StateLine_VI(gy_,iPoint)
        bGradB1z1_I(j) = StateLine_VI(gz_,iPoint)

        j = j + 1
        np = j-1


        call interpolate_mhd(3,(np-1),nStepInterp,(Length1_I(2:np))/Re, B1_I(2:np),BHeidi1_I,LengthHeidi1_I) 
        call interpolate_mhd(3,(np-1),nStepInterp,(Length1_I(2:np))/Re, RadialDist1_I(2:np), RHeidi1_I,LengthHeidi1_I) 
        call interpolate_mhd(3,(np-1),nStepInterp,(Length1_I(2:np))/Re, bGradB1x1_I(2:np), bGradB1xHeidi1_I,LengthHeidi1_I) 
        call interpolate_mhd(3,(np-1),nStepInterp,(Length1_I(2:np))/Re, bGradB1y1_I(2:np), bGradB1yHeidi1_I,LengthHeidi1_I) 
        call interpolate_mhd(3,(np-1),nStepInterp,(Length1_I(2:np))/Re, bGradB1z1_I(2:np), bGradB1zHeidi1_I,LengthHeidi1_I) 

        call interpolate_mhd(3,(np-1),nStepInterp,(Length1_I(2:np))/Re, Bx1_I(2:np), BxHeidi1_I,LengthHeidi1_I) 
        call interpolate_mhd(3,(np-1),nStepInterp,(Length1_I(2:np))/Re, By1_I(2:np), ByHeidi1_I,LengthHeidi1_I) 
        call interpolate_mhd(3,(np-1),nStepInterp,(Length1_I(2:np))/Re, Bz1_I(2:np), BzHeidi1_I,LengthHeidi1_I) 

        iLine = StateLine_VI(1,iPoint)     
        iR    = iRiTiDir_DI(1,iLine)
        iT    = iRiTiDir_DI(2,iLine)
        iDir  = iRiTiDir_DI(3,iLine)



        if (iDir ==1) then  ! Northern hemisphere
           BHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) = BHeidi1_I(:)
           SHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) = LengthHeidi1_I(:)
           RHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) = RHeidi1_I(:)

           bGradB1xHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) =  bGradB1xHeidi1_I(:)
           bGradB1yHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) =  bGradB1yHeidi1_I(:)
           bGradB1zHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) =  bGradB1zHeidi1_I(:)

           BrHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) =  BxHeidi1_I(:)
           BThetaHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) =  ByHeidi1_I(:)
           BPhiHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) =  BzHeidi1_I(:)
           
        end if


        if (iDir ==2) then     ! Southern hemisphere
           BHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = BHeidi1_I(nStepInterp:1:-1) 
           SHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = LengthHeidi1_I(nStepInterp:1:-1) 
           RHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = RHeidi1_I(nStepInterp:1:-1) 

           bGradB1xHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = bGradB1xHeidi1_I(nStepInterp:1:-1) 
           bGradB1yHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = bGradB1yHeidi1_I(nStepInterp:1:-1) 
           bGradB1zHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = bGradB1zHeidi1_I(nStepInterp:1:-1) 

           BrHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = BxHeidi1_I(nStepInterp:1:-1) 
           BThetaHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = ByHeidi1_I(nStepInterp:1:-1) 
           BPhiHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = BzHeidi1_I(nStepInterp:1:-1) 

        end if

        BHeidi_III(nPointEq,iR,iT) = B1_I(1)
        SHeidi_III(nPointEq,iR,iT) = Length1_I(1)
        RHeidi_III(nPointEq,iR,iT) = RadialDist1_I(1)

        bGradB1xHeidi_III(nPointEq,iR,iT) =  bGradB1x1_I(1)
        bGradB1yHeidi_III(nPointEq,iR,iT) =  bGradB1y1_I(1)
        bGradB1zHeidi_III(nPointEq,iR,iT) =  bGradB1z1_I(1)

        BrHeidi_III(nPointEq,iR,iT)  = Bx1_I(1)
        BThetaHeidi_III(nPointEq,iR,iT)  = By1_I(1)
        BPhiHeidi_III(nPointEq,iR,iT)  = Bz1_I(1)

     end if


     if ((StateLine_VI(1,iPoint) /= iLineLast) .and. (iPoint > 1)) then   
        np = i-1

        call interpolate_mhd(3,(np-1),nStepInterp,(Length_I(2:np))/Re,B_I(2:np),BHeidi_I,LengthHeidi_I)
        call interpolate_mhd(3,(np-1),nStepInterp,(Length_I(2:np))/Re,RadialDist_I(2:np),RHeidi_I,LengthHeidi_I) 
        call interpolate_mhd(3,(np-1),nStepInterp,(Length_I(2:np))/Re, bGradB1x_I(2:np), bGradB1xHeidi_I,LengthHeidi_I) 
        call interpolate_mhd(3,(np-1),nStepInterp,(Length_I(2:np))/Re, bGradB1y_I(2:np), bGradB1yHeidi_I,LengthHeidi_I) 
        call interpolate_mhd(3,(np-1),nStepInterp,(Length_I(2:np))/Re, bGradB1z_I(2:np), bGradB1zHeidi_I,LengthHeidi_I) 

        call interpolate_mhd(3,(np-1),nStepInterp,(Length_I(2:np))/Re, Bx_I(2:np), BxHeidi_I, LengthHeidi_I) 
        call interpolate_mhd(3,(np-1),nStepInterp,(Length_I(2:np))/Re, By_I(2:np), ByHeidi_I, LengthHeidi_I) 
        call interpolate_mhd(3,(np-1),nStepInterp,(Length_I(2:np))/Re, Bz_I(2:np), BzHeidi_I, LengthHeidi_I) 
       

 
        iLine = StateLine_VI(1,iPoint)

        iR   = iRiTiDir_DI(1,iLine)
        iT   = iRiTiDir_DI(2,iLine)
        iDir = iRiTiDir_DI(3,iLine)

        if (iDir ==1) then  ! Northern hemisphere
           BHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) = BHeidi_I(:)
           SHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) = LengthHeidi_I(:)
           RHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) = RHeidi_I(:)

           bGradB1xHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) = bGradB1xHeidi_I(:)
           bGradB1yHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) = bGradB1yHeidi_I(:)
           bGradB1zHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) = bGradB1zHeidi_I(:)

           BrHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) = BxHeidi_I(:)
           BThetaHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) = ByHeidi_I(:)
           BPhiHeidi_III((nPointEq+ 1):(nStep - nStepInside),iR,iT) = BzHeidi_I(:)

        end if


        if (iDir ==2) then     ! Southern hemisphere
           BHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = BHeidi_I(nStepInterp:1:-1)
           SHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = LengthHeidi_I(nStepInterp:1:-1) 
           RHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = RHeidi_I(nStepInterp:1:-1) 

           bGradB1xHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = bGradB1xHeidi_I(nStepInterp:1:-1) 
           bGradB1yHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = bGradB1yHeidi_I(nStepInterp:1:-1) 
           bGradB1zHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = bGradB1zHeidi_I(nStepInterp:1:-1) 

           BrHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = BxHeidi_I(nStepInterp:1:-1) 
           BThetaHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = ByHeidi_I(nStepInterp:1:-1) 
           BPhiHeidi_III((nStepInside + 1):(nStepInside + nStepInterp),iR,iT) = BzHeidi_I(nStepInterp:1:-1) 

        end if

        BHeidi_III(nPointEq,iR,iT) = B_I(1)
        SHeidi_III(nPointEq,iR,iT) = Length_I(1)
        RHeidi_III(nPointEq,iR,iT) = RadialDist_I(1)

        bGradB1xHeidi_III(nPointEq,iR,iT) = bGradB1x_I(1)
        bGradB1yHeidi_III(nPointEq,iR,iT) = bGradB1y_I(1)
        bGradB1zHeidi_III(nPointEq,iR,iT) = bGradB1z_I(1)

        BrHeidi_III(nPointEq,iR,iT) = Bx_I(1)
        BThetaHeidi_III(nPointEq,iR,iT) = By_I(1)
        BPhiHeidi_III(nPointEq,iR,iT) = Bz_I(1)

        i = 1
        iLineLast = StateLine_VI(1,iPoint)
     end if


     !B field in Gauss
     B_I(i) = 10000.0*sqrt(StateLine_VI(BX_,iPoint)**2+ &
          StateLine_VI(BY_,iPoint)**2 + StateLine_VI(BZ_,iPoint)**2)
     Length_I (i) = StateLine_VI(S_,iPoint)
     RadialDist_I(i) = sqrt(StateLine_VI(X_,iPoint)**2 + &
          StateLine_VI(Y_,iPoint)**2 + StateLine_VI(Z_,iPoint)**2 )

     bGradB1x_I(i) = StateLine_VI(gx_,iPoint)
     bGradB1y_I(i) = StateLine_VI(gy_,iPoint)
     bGradB1z_I(i) = StateLine_VI(gz_,iPoint)
     
     Bx_I(i) = StateLine_VI(BX_,iPoint)
     By_I(i) = StateLine_VI(BY_,iPoint)
     Bz_I(i) = StateLine_VI(BZ_,iPoint)
     
     iLineLast = StateLine_VI(1,iPoint)

     i = i + 1

  end do

  deallocate(B_I); deallocate(Length_I); deallocate(RadialDist_I);
  deallocate(B1_I); deallocate(Length1_I); deallocate(RadialDist1_I);
  deallocate(bGradB1x1_I); deallocate(bGradB1y1_I); deallocate(bGradB1z1_I);
  deallocate(bGradB1x_I); deallocate(bGradB1y_I); deallocate(bGradB1z_I);
  deallocate(Bx_I); deallocate(By_I); deallocate(Bz_I);
  deallocate(Bx1_I); deallocate(By1_I); deallocate(Bz1_I);

  !\
  ! Fill in the values of the B field with dipole values inside rBoundary ( = 2.5 Re)
  !/


  !  open (unit=3,file='BFieldMHD.dat')
  !  write(3,*) 'iT,iR,iPoint,BField'


  do iR = 1, nR
     if (LZ(iR) <= rBoundary) then
        LatMax =  acos(sqrt(1./LZ(iR)))
        ! Fill in the dipole values
        LatMin = - LatMax
        dLat   = (LatMax-LatMin)/(nStep-1)
        Lat = LatMin
        do iStep = 1, nStep
           SinLat2 = sin(Lat)**2
           CosLat2 = 1.0 - SinLat2  
           bDipole_II(iStep,iR) = DipoleStrength*sqrt(1.0+3.0*SinLat2)/(LZ(iR)*CosLat2)**3
           rDipole_II(iStep,iR) = LZ(iR)*CosLat2
           sDipole_II(iStep,iR) = dipole_length(LZ(ir),LatMin,Lat) 
           
           BrDipole_II(iStep,iR) = (-2.*sin(Lat))/rDipole_II(iStep,iR)**3
           BthetaDipole_II(iStep,iR) = cos(Lat)/rDipole_II(iStep,iR)**3
           BphiDipole_II(iStep,iR) = 0.0              
           
           x = sin(Lat)
           r = LZ(iR) * (cos(Lat))**2
           !gradB0R = gradient of (B0 on r direction)
           
           gradB0R1= DipoleStrength*(6. * x)/r**4
           gradB0R2 = DipoleStrength*(2. * sqrt(1.-x**2))/r**4
           
           gradB0Theta1 = DipoleStrength*(3. * sqrt(1.-x**2))/r**4
           gradB0Theta2 = DipoleStrength*( -x/r**4)
                                
           Tr =  BrDipole_II(iStep,iR)/bDipole_II(iStep,iR) * gradB0R1 +&
                BThetaDipole_II(iStep,iR)/bDipole_II(iStep,iR) * gradB0R2

           Ttheta =  BrDipole_II(iStep,iR)/bDipole_II(iStep,iR) * gradB0Theta1 +&
                BThetaDipole_II(iStep,iR)/bDipole_II(iStep,iR) * gradB0Theta2
                
           bGradB1x_II(iStep,iR) = Tr 
           bGradB1y_II(iStep,iR) = Ttheta  

           Lat = Lat + dLat
        end do
     end if
  end do



  do iR = 1, nR
     if (LZ(iR) >rBoundary) then
        LatMax =  acos(sqrt(1./LZ(iR)))
        LatMin = acos(sqrt(rBoundary/LZ(iR)))
        dLat   = (LatMax-LatMin)/(nStepInside-1)         
        Lat = LatMin
        ! Northern part
        do iStep = 1,nStepInside
           SinLat2 = sin(Lat)**2
           CosLat2 = 1.0 - SinLat2  
           bDipoleN_II(iStep,iR) = DipoleStrength*sqrt(1.0+3.0*SinLat2)/(LZ(iR)*CosLat2)**3
           rDipoleN_II(iStep,iR) = LZ(iR)*CosLat2
           sDipoleN_II(iStep,iR) = dipole_length(LZ(ir),LatMin,Lat) 
           
           BrDipoleN_II(iStep,iR) = (-2.*sin(Lat))/rDipoleN_II(iStep,iR)**3
           BthetaDipoleN_II(iStep,iR) = cos(Lat)/rDipoleN_II(iStep,iR)**3
           BphiDipoleN_II(iStep,iR) = 0.0  

           x = sin(Lat)
           r = LZ(iR) * (cos(Lat))**2
           !gradB0R = gradient of (B0 on r direction)
           
           gradB0R1= DipoleStrength* (6. * x)/r**4
           gradB0R2 = DipoleStrength* (2. * sqrt(1.-x**2))/r**4
           
           gradB0Theta1 = DipoleStrength* (3. * sqrt(1.-x**2))/r**4
           gradB0Theta2 = DipoleStrength*(- x/r**4)
                                
           Tr =  BrDipoleN_II(iStep,iR)/bDipoleN_II(iStep,iR) * gradB0R1 +&
                BThetaDipoleN_II(iStep,iR)/bDipoleN_II(iStep,iR) * gradB0R2

           Ttheta =  BrDipoleN_II(iStep,iR)/bDipoleN_II(iStep,iR) * gradB0Theta1 +&
                BThetaDipoleN_II(iStep,iR)/bDipoleN_II(iStep,iR) * gradB0Theta2
                
           bGradB1xN_II(iStep,iR) = Tr 
           bGradB1yN_II(iStep,iR) = Ttheta  

           Lat = Lat + dLat

        end do

        ! Southern part
        Lat = - LatMax
        do iStep = 1,nStepInside
           SinLat2 = sin(Lat)**2
           CosLat2 = 1.0 - SinLat2  
           bDipoleS_II(iStep,iR) = DipoleStrength*sqrt(1.0+3.0*SinLat2)/(LZ(iR)*CosLat2)**3
           rDipoleS_II(iStep,iR) = LZ(iR)*CosLat2
           sDipoleS_II(iStep,iR) = dipole_length(LZ(ir),LatMin,Lat) 
           
           BrDipoleS_II(iStep,iR) = (-2.*sin(Lat))/rDipoleS_II(iStep,iR)**3
           BthetaDipoleS_II(iStep,iR) = cos(Lat)/rDipoleS_II(iStep,iR)**3
           BphiDipoleS_II(iStep,iR) = 0.0  

           x = sin(Lat)
           r = LZ(iR) * (cos(Lat))**2
           !gradB0R = gradient of (B0 on r direction)
           
           gradB0R1=  DipoleStrength*(6. * x)/r**4
           gradB0R2 =  DipoleStrength*(2. * sqrt(1.-x**2))/r**4
           
           gradB0Theta1 =  DipoleStrength*(3. * sqrt(1.-x**2))/r**4
           gradB0Theta2 =  DipoleStrength*(-x/r**4)
                                
           Tr =  BrDipoleS_II(iStep,iR)/bDipoleS_II(iStep,iR) * gradB0R1 +&
                BThetaDipoleS_II(iStep,iR)/bDipoleS_II(iStep,iR) * gradB0R2

           Ttheta =  BrDipoleS_II(iStep,iR)/bDipoleS_II(iStep,iR) * gradB0Theta1 +&
                BThetaDipoleS_II(iStep,iR)/bDipoleS_II(iStep,iR) * gradB0Theta2
                
           bGradB1xN_II(iStep,iR) = Tr 
           bGradB1yN_II(iStep,iR) = Ttheta 

           Lat = Lat + dLat
        end do
     end if

  end do



  !\
  ! Convert to Heidi grid B field
  !/

  ns = nStepInside

  do iT = 1,nT
     do iR = 1, nR
        if (LZ(iR) > rBoundary) then
           BHeidi_III(1:nStepInside,iR,iT) = bDipoleS_II(:,iR)   
           BHeidi_III((nStep-nStepInside +1):nStep,iR,iT) = bDipoleN_II(:,iR)
           RHeidi_III(1:nStepInside,iR,iT) = rDipoleS_II(:,iR)   
           RHeidi_III((nStep-nStepInside +1):nStep,iR,iT) = rDipoleN_II(:,iR)
           SHeidi_III(1:nStepInside,iR,iT) = sDipoleS_II(:,iR)   
           SHeidi_III((nStep-nStepInside +1):nStep,iR,iT) = sDipoleN_II(:,iR)
           
           
           BrHeidi_III(1:nStepInside,iR,iT) = bRDipoleS_II(:,iR) 
           BrHeidi_III((nStep-nStepInside +1):nStep,iR,iT) = BrDipoleN_II(:,iR)

           BThetaHeidi_III((nStep-nStepInside +1):nStep,iR,iT) = BthetaDipoleN_II(:,iR)
           BThetaHeidi_III(1:nStepInside,iR,iT) = BthetaDipoleS_II(:,iR) 

           BPhiHeidi_III((nStep-nStepInside +1):nStep,iR,iT) = BPhiDipoleN_II(:,iR)
           BPhiHeidi_III(1:nStepInside,iR,iT) = bPhiDipoleS_II(:,iR) 

           bGradB1xHeidi_III(1:nStepInside,iR,iT) =  bGradB1xS_II(:,iR)
           bGradB1yHeidi_III(1:nStepInside,iR,iT) =  bGradB1yS_II(:,iR)
           bGradB1zHeidi_III(1:nStepInside,iR,iT) =  0.0

           bGradB1xHeidi_III((nStep-nStepInside +1):nStep,iR,iT) = bGradB1xN_II(:,iR)
           bGradB1yHeidi_III((nStep-nStepInside +1):nStep,iR,iT) = bGradB1yN_II(:,iR)
           bGradB1zHeidi_III((nStep-nStepInside +1):nStep,iR,iT) = 0.0


        end if
        if (LZ(iR) <= rBoundary) then
           BHeidi_III(:,iR,iT) = bDipole_II(:,iR)
           RHeidi_III(:,iR,iT) = rDipole_II(:,iR)
           SHeidi_III(:,iR,iT) = sDipole_II(:,iR)

           BrHeidi_III(:,iR,iT) = BrDipole_II(:,iR)
           BThetaHeidi_III(:,iR,iT) = BthetaDipole_II(:,iR)
           BPhiHeidi_III(:,iR,iT) = BPhiDipole_II(:,iR)
           
           bGradB1xHeidi_III(:,iR,iT) = bGradB1x_II(:,iR)
           bGradB1yHeidi_III(:,iR,iT) = bGradB1y_II(:,iR)
           bGradB1zHeidi_III(:,iR,iT) = 0.0

        end if
     end do
  end do

  BHeidi_III(:,:,nT) = Bheidi_III(:,:,1)
  RHeidi_III(:,:,nT) = RHeidi_III(:,:,1)
  SHeidi_III(:,:,nT) = SHeidi_III(:,:,1)
  
  BrHeidi_III(:,:,nT)     = BrHeidi_III(:,:,1)
  BThetaHeidi_III(:,:,nT) = BThetaHeidi_III(:,:,1)
  BPhiHeidi_III(:,:,nT)   = BPhiHeidi_III(:,:,1)
  
  bGradB1xHeidi_III(:,:,nT) = bGradB1xHeidi_III(:,:,1)
  bGradB1yHeidi_III(:,:,nT) = bGradB1yHeidi_III(:,:,1)  
  bGradB1zHeidi_III(:,:,nT) = bGradB1zHeidi_III(:,:,1)

end subroutine IM_put_from_gm_line

!==============================================================================

subroutine IM_put_sat_from_gm(nSats, Buffer_I, Buffer_III)
  ! Puts satellite locations and names from GM into IM variables.
!!!DTW 200

  use ModHeidiSatellites
  use ModNumConst,   ONLY: cDegToRad

  implicit none
  character (len=*),parameter :: NameSub='IM_put_sat_from_gm'

  ! Arguments
  integer, intent(in)            :: nSats
  real, intent(in)               :: Buffer_III(3,2,nSats)
  character(len=100), intent(in) :: Buffer_I(nSats)

  ! Internal variables
  integer :: iError, iSat, l1, l2

  DoWriteSats = .true.
  nImSats = nSats

  if (nImSats > nMaxSatellites) then
     write(*,*) "nImSats > nMaxSatellites"
     call CON_stop("Stoping in routine " // NameSub)
  endif

  ! Assign incoming values, remove path and extension from name.
  SatLoc_3I = Buffer_III
  do iSat=1, nSats
     l1 = index(Buffer_I(iSat), '/', back=.true.) + 1
     l2 = index(Buffer_I(iSat), '.') - 1
     if (l1-1<=0) l1=1
     if (l2+1<=0) l2=len_trim(Buffer_I(iSat))
     NameSat_I(iSat) = Buffer_I(iSat)(l1:l2)
  end do

  ! Change to correct units (degrees to radians)
  SatLoc_3I(1,2,:) = (90. - SatLoc_3I(1,2,:)) * cDegToRad
  SatLoc_3I(2,2,:) =        SatLoc_3I(2,2,:)  * cDegToRad

end subroutine IM_put_sat_from_gm

!==============================================================================

subroutine IM_get_for_gm(Buffer_IIV,iSizeIn,jSizeIn,nVar,NameVar)

  use CON_time, ONLY : get_time
  use ModNumConst, ONLY: cPi, cDegToRad
  use ModConst, ONLY: cProtonMass
  use ModIonoHeidi
  use ModHeidiSize
  use ModHeidiCurrents
  implicit none
  character (len=*),parameter :: NameSub='IM_get_for_gm'

  integer, intent(in)                                :: iSizeIn,jSizeIn,nVar
  real, dimension(iSizeIn,jSizeIn,nVar), intent(out) :: Buffer_IIV
  character (len=*),intent(in)                       :: NameVar

  integer, parameter :: pres_=1, dens_=2

  integer :: iLat, iLon, l, k
  real :: T, P, latsHeidi(NR), mltsHeidi(NT)

  logical :: DoTest, DoTestMe
  !--------------------------------------------------------------------------
  call CON_set_do_test(NameSub, DoTest, DoTestMe)
  if (DoTestMe) &
       write(*,*)NameSub,' starting with iSizeIn,jSizeIn,nVar,NameVar=',&
       iSizeIn,jSizeIn,nVar,NameVar

  if(NameVar /= 'p:rho') &
       call CON_stop(NameSub//' invalid NameVar='//NameVar)

  if(iSizeIn /= IONO_nTheta*2-1 .or. jSizeIn /= IONO_nPsi)then
     write(*,*)NameSub//' incorrect buffer size=',iSizeIn,jSizeIn
     call CON_stop(NameSub//' SWMF_ERROR')
  end if

  Buffer_IIV = -1.0

  ! eden and rnht are defined on a nr,nt grid
  ! where do I get latitude and mlt on nr,nt grid?

  ! the ionosphere and magnetosphere grid are shifted by 1, such that the
  ! ionosphere grid has an extra point at the lower end (and 2 at the upper)

  do iLon=1,jo
     mltsHeidi(iLon) = LonFac(iLon) * cPi / 12.0 
  enddo
  mltsHeidi(jo+1) = mltsHeidi(1) + 2.0 * cPi

  do iLat=1,io
     latsHeidi(iLat) = Latfac(iLat+1) * cDegToRad
  enddo

  do iLat = 1, IONO_nTheta
     do iLon = 1, IONO_nPsi

        T = cPi/2.0 - IONO_NORTH_Theta(iLat,iLon)
        P = mod(IONO_NORTH_Psi(iLat,iLon) + cPi, cPi*2)

        if ((T < latsHeidi(1)).or.(T > latsHeidi(io))) then
           Buffer_IIV(iLat,iLon,:) = -1.0
        else 

           k = 1
           do while (T > latsHeidi(k))
              k = k + 1
           enddo

           l = 1
           do while (P > mltsHeidi(l))
              l = l + 1
           enddo

           ! This takes the nearest cell, and does not do linear interpolation

           ! Add together pressures from H+ (2) and O+ (4)
           ! Convert from keV/cc to Pa
           Buffer_IIV(iLat,iLon,pres_) = &
                eden(k,l,2)*0.1602*1.0e-9 + &
                eden(k,l,4)*0.1602*1.0e-9

           ! Add together density from H+ (2) and O+ (4)
           ! Convert from #/cc to kg/m3
           Buffer_IIV(iLat,iLon,dens_) = &
                rnht(k,l,2)*1.0e6*cProtonMass + &
                rnht(k,l,4)*1.0e6*cProtonMass*16.0

        endif

     enddo

  enddo

  do iLat = 1, IONO_nTheta
     do iLon = 1, IONO_nPsi

        T = IONO_SOUTH_Theta(iLat,iLon) - cPi/2
        P = mod(IONO_SOUTH_Psi(iLat,iLon) + cPi, cPi*2)

        if ((T < latsHeidi(1)).or.(T > latsHeidi(io))) then
           Buffer_IIV(iLat,iLon,:) = -1.0
        else 

           k = 1
           do while (T > latsHeidi(k))
              k = k + 1
           enddo

           l = 1
           do while (P > mltsHeidi(l))
              l = l + 1
           enddo

           if (l > 1) l = l - 1

           ! This takes the nearest cell, and does not do linear interpolation

           ! Add together pressures from H+ (2) and O+ (4)
           ! Convert from keV/cc to Pa
           Buffer_IIV(iLat,iLon,pres_) = &
                eden(k,l,2)*0.1602*1.0e-9 + &
                eden(k,l,4)*0.1602*1.0e-9

           ! Add together density from H+ (2) and O+ (4)
           ! Convert from #/cc to kg/m3
           Buffer_IIV(iLat,iLon,dens_) = &
                rnht(k,l,2)*1.0e6*cProtonMass + &
                rnht(k,l,4)*1.0e6*cProtonMass*16.0

        endif

     enddo

  enddo

  ! species = e, H, he, o

!!! RNHT(colat,mlt,species) = density in #/cc
!!! EDEN("                ) = equatorial pressure (keV/cc) (*0.1602 = nPa)

end subroutine IM_get_for_gm

!==============================================================================

subroutine IM_init_session(iSession, TimeSimulation)
  use ModHeidiIO, ONLY: time
  implicit none

  integer,  intent(in) :: iSession       ! session number (starting from 1)
  real,     intent(in) :: TimeSimulation   ! seconds from start time
  logical :: IsUninitialized = .true.
  !--------------------------------------------------------------------------

  Time = TimeSimulation 

  if(IsUninitialized)then
     call heidi_init

     IsUninitialized = .false.
  end if

end subroutine IM_init_session

!==============================================================================
subroutine IM_finalize(TimeSimulation)

  use ModProcIM
  use ModInit, ONLY:nS
  use ModHeidiIO, ONLY :iUnitSw1,iUnitSw2,&
       iUnitMpa,iUnitSopa,iUnitPot,iUnitSal

  implicit none

  real,     intent(in) :: TimeSimulation   ! seconds from start time
  !--------------------------------------------------------------------------

  close(iUnitSal)           ! Closes continuous output file
  close(iUnitSw1)           ! Closes sw1 input file
  close(iUnitSw2)           ! Closes sw2 input file
  close(iUnitMpa)           ! Closes MPA input file
  close(iUnitSopa)          ! Closes SOPA input file
  close(iUnitPot)           ! Closes FPOT input file

end subroutine IM_finalize

!=============================================================================

subroutine IM_run(SimTime, SimTimeLimit)

  use ModHeidiSize, only: dt, dtMax

  implicit none

  real, intent(inout) :: SimTime   ! current time of component
  real, intent(in)    :: SimTimeLimit ! simulation time not to be exceeded

  !--------------------------------------------------------------------------
  Dt = min(DtMax, (SimTimeLimit - SimTime)/2 )

  call heidi_run 

  SimTime = SimTime + dt*2

end subroutine IM_run

!===========================================================================

subroutine IM_save_restart(TimeSimulation)
  implicit none

  real,     intent(in)        :: TimeSimulation   ! seconds from start time
  character(len=*), parameter :: NameSub='IM_save_restart'
  !-------------------------------------------------------------------------
!!! call heidi_save_restart

end subroutine IM_save_restart

!===========================================================================
subroutine IM_put_from_gm_crcm

  ! This subroutine is necessary for HEIDI to run with RBE and should be empty here.
end subroutine IM_put_from_gm_crcm


!===========================================================================

subroutine interpolate_linear_b (nP,Length_I,B_I,nPoint,LengthHeidi_I,BHeidi_I)

  implicit none

  integer, intent(in)  :: nP ! number of points along the field line from BATSRUS
  real,    intent(in)  :: Length_I(nP)
  real,    intent(in)  :: B_I(nP)
  integer, intent(in)  :: nPoint ! number of points on new grid
  real,    intent(out) :: LengthHeidi_I(nPoint)
  real,    intent(out) :: BHeidi_I(nPoint)

  !Local variables
  real    :: dLength, LengthMax,LengthMin
  integer :: iP, iPoint, i
  !--------------------------------------------------------------------------

  LengthMax = Length_I(nP)
  LengthMin = Length_I(1)
  dLength = (LengthMax - LengthMin)/(nPoint - 1)

  ! Linear Interpolation
  do iPoint = 1, nPoint
     LengthHeidi_I(iPoint) = LengthMin + (iPoint - 1) * dLength

     do iP = 1, nP
        if (Length_I(iP) > LengthHeidi_I(iPoint)) then
           i = iP - 1
           BHeidi_I(iPoint) = B_I(i) + (LengthHeidi_I(iPoint) - Length_I(i))*&
                (B_I(i+1) - B_I(i))/(Length_I(i+1) - Length_I(i) )
           exit
        end if
     end do
  end do

end subroutine interpolate_linear_b

!===============================================================================
subroutine reverse(n,A,InvA)

  implicit none

  integer           :: n 
  real,dimension(n) :: A ,invA
  integer           :: i,j
  !-------------------------------------------------------------------------
  do i = 1, n
     j = n -i +1
     InvA(i) = A(j)
  end do

end subroutine reverse
!===============================================================================
real function Lagrange(lHeidi, lMhd_I, bMhd_I, nStepMHD, nOrder)

  implicit none

  real    :: lHeidi           ! find the value of B at this point along the fiedl line
  integer :: nStepMHD         ! number of points along the MHD field line
  real    :: lMhd_I(nStepMHD) ! field line length values from MHD
  real    :: bMhd_I(nStepMHD) ! magnetic fiedl values from MHD
  integer :: nOrder              ! order of interpolation
  real    :: func_I(nStepMHD)
  integer :: i, j, k, l, m
  real    :: y

  !-------------------------------------------------------------------------
  ! Check if the size of the array is larger than the order of interpolation. 
  if (nOrder > nStepMHD)  nOrder = nStepMHD

  ! Check if lHeidi is outside the lMhd(1)-lMhd(nStepMHD) interval. If yes set a boundary value.
  if (lHeidi <= lMhd_I(1)) then
     lagrange = bMhd_I(1)
     return
  end if
  if (lHeidi >= lMhd_I(nStepMHD)) then
     lagrange = bMhd_I(nStepMHD)
     return
  end if

  ! Search to find i so that lMhd(i) < lHeidi < lMhd(i+1)
  i = 1
  j = nStepMHD
  do while (j > i+1)
     k = (i+j)/2
     if (lHeidi < lMhd_I(k)) then
        j = k
     else
        i = k
     end if
  end do

  ! shift i so that will correspond to n-th order of interpolation
  ! the search point will be in the middle in x_i, x_i+1, x_i+2 ...
  i = i + 1 - nOrder/2

  if (i < 1) i=1
  if (i + nOrder > nStepMHD) i = nStepMHD - nOrder + 1

  ! Lagrange interpolation
  y = 0.0
  do m = i, i + nOrder - 1
     func_I(m)=1.0
     do l = i, i + nOrder -1
        if(l /= m) func_I(m)=func_I(m)*(lHeidi-lMhd_I(l))/(lMhd_I(m)-lMhd_I(l))
     end do
     y = y + bMhd_I(m)*func_I(m)
  end do
  lagrange = y
end function lagrange

!===============================================================================

subroutine interpolate_mhd(nOrder,nStepMhd,nStep,lMhd_I,bMhd_I,bHeidi_I,lHeidi_I)

  implicit none

  integer, intent(in)  :: nOrder           ! order of interpolation
  integer, intent(in)  :: nStepMHD         ! number of points along MHD field line
  integer, intent(in)  :: nStep            ! number of points to interpolate onto
  real,    intent(in)  :: lMhd_I(nStepMHD) ! field line length from MHD
  real,    intent(in)  :: bMhd_I(nStepMHD) ! magnetic field values from MHD
  real,    intent(out) :: bHeidi_I(nStep)  ! magnetic field values interpolated 
  real,    intent(out) :: lHeidi_I(nStep)  ! field line length values 
  ! Local Variables
  real    :: LengthMax, LengthMin, dLength
  real    :: lagrange
  integer :: iStep
  !-------------------------------------------------------------------------

  LengthMax = lMhd_I(nStepMhd)
  LengthMin = LMhd_I(1)
  dLength = (LengthMax - LengthMin)/(nStep - 1)

  do iStep = 1, nStep
     lHeidi_I(iStep) = LengthMin + (iStep - 1) * dLength
     bHeidi_I(iStep) = lagrange(lHeidi_I(iStep),lMhd_I,bMhd_I,nStepMhd, nOrder+1)
  end do

end subroutine interpolate_mhd

!===============================================================================
