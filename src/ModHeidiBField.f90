!  Copyright (C) 2002 Regents of the University of Michigan, portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
module ModHeidiBField

  implicit none

contains
  !==================================================================================
  subroutine initialize_b_field (L_I, Phi_I, nPoint, nR, nPhi, bFieldMagnitude_III, &
       RadialDistance_III, Length_III, dLength_III,GradBCrossB_VIII,GradB_VIII,dBdt_III)

    use ModProcHEIDI,  ONLY: iProc
    use ModHeidiSize,  ONLY: dt
    use ModHeidiInput, ONLY: TypeBField
    use ModNumConst,   ONLY: cTiny
    use ModHeidiMain,  ONLY: LZ,BHeidi_III, SHeidi_III, RHeidi_III,&
         bGradB1xHeidi_III, bGradB1yHeidi_III, bGradB1zHeidi_III,&
         BxHeidi_III, ByHeidi_III, BzHeidi_III, t, Xyz_VIII, &
         Re
    use ModCoordTransform, ONLY: cross_product, rot_xyz_sph
    use ModPlotFile,       ONLY: save_plot_file
    use ModInit, ONLY:i3
    

    integer, intent(in)    :: nPoint , nR, nPhi
    real,    intent(in)    :: L_I(nR),Phi_I(nPhi)        
    real,    intent(out)   :: bFieldMagnitude_III(nPoint,nR,nPhi) ! Magnitude of magnetic field 
    real,    intent(out)   :: Length_III(nPoint,nR,nPhi)          ! Length of the field line
    real,    intent(out)   :: RadialDistance_III(nPoint,nR,nPhi)  ! Radial distance 
    real,    intent(out)   :: dLength_III(nPoint-1,nR,nPhi)       ! Length interval between i and i+1
    !Local Variables    
    real                   :: LatMin, LatMax, Lat,dLat,LatMin2, LatMax2, LatMinMax
    real                   :: SinLat2, CosLat2, BetaF, dLatNew, beta1, beta2
    integer                :: iR, iPhi,iPoint     
    real, dimension(nPoint,nR,nPhi), intent(out)    :: dBdt_III
    real, dimension(3,nPoint,nR,nPhi), intent(out) :: GradB_VIII, GradBCrossB_VIII
    real, dimension(3,nPoint,nR,nPhi) :: GradB0x_VIII, GradB0y_VIII, GradB0z_VIII

    real, dimension(3)  :: GradB2_D, GradBCrossBsph_D(3),GradBxyz_D(3),GradBCrossBxyz_D(3)
    real, dimension(3,3):: XyzSph_DD
    real, parameter     :: DipoleStrength =  -0.32   ! nTm^-3
    real                :: DirBx, DirBy, DirBz, Tx, Ty,Tz

    ! Temp var; Should be removed
    real :: b_DII(3,nPoint,nR)
    real :: Coord_DII(2,nPoint,nR)
    !----------------------------------------------------------------------------------
    select case(TypeBField)
       
       !\
       ! Magnetic field from BATS_R_US code; only in the coupled mode.
       !/
    case('mhd')
       write(*,*) 'TimStepCounter = ', i3
       if (i3<=2) then
          write(*,*) 'CASE MHD--------->INITIALIZE B FIED'
          write(*,*) 'Simulation Time, TimeStep, 2*TimeStep=',t, dt, 2.*dt    
        
        ! call get_analytical_field(L_I, Phi_I, nPoint, nR, nPhi, bFieldMagnitude_III,  bField_VIII,&
        !       RadialDistance_III, Length_III, GradBCrossB_VIII,GradB_VIII,dBdt_III)
 !        call  get_stretched_field(L_I, Phi_I, nPoint, nR, nPhi, bFieldMagnitude_III,&
!               RadialDistance_III, Length_III, GradBCrossB_VIII,GradB_VIII,dBdt_III)
          
          call  get_asym_stretched_field(L_I, Phi_I, nPoint, nR, nPhi, bFieldMagnitude_III,&
               RadialDistance_III, Length_III, GradBCrossB_VIII,GradB_VIII,dBdt_III)
       else

          write(*,*) 'REAL MHD------>Simulation Time, TimeStep, 2*TimeStep=',t, dt, 2.*dt
          
          
          bFieldMagnitude_III = BHeidi_III
          
           write(*,*) 'BField = ', BHeidi_III(44,18,4)

          RadialDistance_III  = RHeidi_III 

          write(*,*) ' RadialDistance_III',  RadialDistance_III(44,18,4)

          Length_III          = SHeidi_III 

          write(*,*) ' Length_III',  Length_III(4,8,4)

          call get_gradB0(nPoint,nR,nPhi,Phi_I, GradB0x_VIII, GradB0y_VIII, GradB0z_VIII)

          write(*,*) ' call get_gradB0(n)' 
          dBdt_III=0.0

          ! Calculation of gradB and gradBcrossB
          do iPhi = 1, nPhi
             do iR = 1, nR
                do iPoint =1, nPoint
                   Lat = atan(Xyz_VIII(3,iPoint,iR,iPhi)/&
                        sqrt(Xyz_VIII(1,iPoint,iR,iPhi)**2 + Xyz_VIII(2,iPoint,iR,iPhi)**2))

                   DirBx     = BxHeidi_III(iPoint,iR,iPhi)/BHeidi_III(iPoint,iR,iPhi)
                   DirBy     = ByHeidi_III(iPoint,iR,iPhi)/BHeidi_III(iPoint,iR,iPhi)
                   DirBz     = BzHeidi_III(iPoint,iR,iPhi)/BHeidi_III(iPoint,iR,iPhi)

                   Tx = DirBx * GradB0x_VIII(1,iPoint,iR,iPhi) + &
                        DirBy * GradB0y_VIII(1,iPoint,iR,iPhi) + &
                        DirBz * GradB0z_VIII(1,iPoint,iR,iPhi)  

                   Ty = DirBx * GradB0x_VIII(2,iPoint,iR,iPhi) + &
                        DirBy * GradB0y_VIII(2,iPoint,iR,iPhi) + &
                        DirBz * GradB0z_VIII(2,iPoint,iR,iPhi)  

                   Tz = DirBx * GradB0x_VIII(3,iPoint,iR,iPhi) + &
                        DirBy * GradB0y_VIII(3,iPoint,iR,iPhi) + &
                        DirBz * GradB0z_VIII(3,iPoint,iR,iPhi)  

                 !  write(*,*) 'Tx, Ty, Tz =', Tx, Ty, Tz

                   ! Contains both dipolar and B1 contribution.

                   GradBxyz_D(1) = Tx + bGradB1xHeidi_III(iPoint,iR,iPhi)
                   GradBxyz_D(2) = Ty + bGradB1yHeidi_III(iPoint,iR,iPhi)
                   GradBxyz_D(3) = Tz + bGradB1zHeidi_III(iPoint,iR,iPhi)

                   ! Grad(B^2) = B Grad B
                   GradB2_D =  BHeidi_III(iPoint,iR,iPhi) * GradBxyz_D

                   GradBCrossBxyz_D(:) = cross_product(GradB2_D(1), GradB2_D(2),GradB2_D(3),&
                        BxHeidi_III(iPoint,iR,iPhi),ByHeidi_III(iPoint,iR,iPhi),BzHeidi_III(iPoint,iR,iPhi))
                   !\
                   ! Conversion from cartesian to spherical
                   !/

                   ! Rotation Matrix from cartesian to spherical
                   XyzSph_DD = rot_xyz_sph(Xyz_VIII(1,iPoint,iR,iPhi),&
                        Xyz_VIII(2,iPoint,iR,iPhi), Xyz_VIII(3,iPoint,iR,iPhi))    

                   GradB_VIII(:,iPoint,iR,iPhi)       = matmul(GradBxyz_D, XyzSph_DD)

                   GradBCrossBSph_D = matmul(GradBCrossBxyz_D,XyzSph_DD) 
                   GradBCrossB_VIII(1,iPoint,iR,iPhi) =  GradBCrossBSph_D(1)
                   GradBCrossB_VIII(2,iPoint,iR,iPhi) =  GradBCrossBSph_D(2) *  1./(Re*LZ(iR))
                   GradBCrossB_VIII(3,iPoint,iR,iPhi) =  GradBCrossBSph_D(3) * 1./(Re*LZ(iR)* cos(Lat))
                end do
             end do
          end do
          
          if(iProc == 0)then
             ! Write out values for testing; Should be removed
             do iPhi =1, 1
                do iR =1, nR
                   do iPoint =1, nPoint
                      B_DII(1,iPoint,iR)     = BxHeidi_III(iPoint,iR,iPhi)
                      B_DII(2,iPoint,iR)     = ByHeidi_III(iPoint,iR,iPhi)
                      B_DII(3,iPoint,iR)     = BzHeidi_III(iPoint,iR,iPhi)
                      Coord_DII(1,iPoint,iR) = Xyz_VIII(1,iPoint,iR,iPhi)/Re
                      Coord_DII(2,iPoint,iR) = Xyz_VIII(3,iPoint,iR,iPhi)/Re
                   end do
                end do
             end do

             call save_plot_file('BField_mhd.out', & 
                  StringHeaderIn = 'Magnetic field', &
                  NameVarIn = 'x z bx by bz', &
                  CoordIn_DII = Coord_DII,&
                  VarIn_VII = b_DII)
          end if
       end if

       write(*,*) 'Done with MHD' 


       !\
       ! Dipole magnetic field with uniform number of points along the field line. 
       ! More refined at the equator, coarser towards the poles
       !/
    case('uniform_dipole')

      
       do iPhi =1, nPhi
          do iR =1, nR 
             LatMax =  acos(sqrt(1./L_I(iR)))
             LatMin = -LatMax
             dLat   = (LatMax-LatMin)/(nPoint-1)
             Lat = LatMin

             do iPoint = 1, nPoint
                SinLat2 = sin(Lat)**2
                CosLat2 = 1.0 - SinLat2  
                bFieldMagnitude_III(iPoint,iR,iPhi) = DipoleStrength*sqrt(1.0+3.0*SinLat2)/(L_I(iR)*CosLat2)**3
                RadialDistance_III(iPoint,iR,iPhi) = L_I(iR)*CosLat2
                Length_III(iPoint,iR,iPhi) = dipole_length(L_I(ir),LatMin,Lat) 
                Lat = Lat + dLat
             end do
          end do
       end do

           
       !\
       ! Dipole magnetic field with non-uniform number of points along the field line. 
       ! More refined at the equator, coarser towards the poles
       !/

    case('nonuniformDipole')
       do iPhi =1, nPhi
          do iR =1, nR 
             LatMax =  acos(sqrt(1./L_I(iR)))
             LatMin = -LatMax
             dLat   = (LatMax-LatMin)/(nPoint-1)
             Lat = LatMin

             LatMin2 = LatMin**2
             LatMax2 = LatMax**2
             LatMinMax = LatMin*LatMax

             beta1 = 6.0*(-nPoint+cTiny*nPoint+1.0)*(nPoint-1.0) 
             beta2 = nPoint*(2.0*LatMax2*nPoint + 2.0*LatMinMax*nPoint + 2.0*LatMin2*nPoint &
                  - 4.0*LatMinMax - LatMin2 - LatMax2)
             BetaF = - beta1/beta2  

             do iPoint = 1, nPoint
                Lat = LatMin+(iPoint-1)*dLat
                SinLat2 = sin(Lat)**2
                CosLat2 = 1.0 - SinLat2
                bFieldMagnitude_III(iPoint,iR,iPhi) = DipoleStrength*sqrt(1.0+3.0*SinLat2)/(L_I(iR)*CosLat2)**3
                RadialDistance_III(iPoint,iR,iPhi) = L_I(iR)*CosLat2
                Length_III(iPoint,iR,iPhi) = dipole_length(L_I(iR),LatMin,Lat) 
                dLatNew =(BetaF*(LatMin+(iPoint-1)*dLat)**2+cTiny)*dLat
                Lat = Lat+dLatNew
             end do
          end do
       end do

       !\
       ! Stretched dipole magnetic field, with azimuthal symmetry. 
       !/

    case('stretched_dipole1')
       write(*,*) 'stretched_dipole1'
       ! get_stretched_dipole gives the same results for dipole field as uniform_dipole!!!!!!!!
       call  get_stretched_dipole(L_I, Phi_I, nPoint, nR, nPhi, bFieldMagnitude_III, &
            RadialDistance_III, Length_III, GradBCrossB_VIII,GradB_VIII, dBdt_III)
       
    case('stretched_dipole2')
       write(*,*) 'stretched_dipole2'
       call  get_asym_stretched_field(L_I, Phi_I, nPoint, nR, nPhi, bFieldMagnitude_III,&
            RadialDistance_III, Length_III, GradBCrossB_VIII,GradB_VIII,dBdt_III)
    end select
    
    do iPhi =1, nPhi
       do iR =1, nR 
          do iPoint = 1, nPoint-1
             dLength_III(iPoint,iR,iPhi) = Length_III(iPoint+1,iR,iPhi) - Length_III(iPoint,iR,iPhi)
          end do
       end do
    end do


  end subroutine initialize_b_field
  !==================================================================================
  subroutine find_mirror_points (nPoint, PitchAngle, bField_I, bMirror,iMirror_II)

    use ModNumConst,   ONLY: cTiny

    integer, intent(in) :: nPoint           ! Number of points along the field line
    real, intent(in)    :: PitchAngle       ! Pitch angle values
    real, intent(in)    :: bField_I(nPoint) ! Magnetic field values
    real, intent(out)   :: bMirror          ! B magnitude at mirror points    
    real                :: bMin,bMax        ! Minimum value of magnetic field along a field line
    integer             :: iMinB,iMaxB      ! Location of minimum B
    integer,intent(out) :: iMirror_II(2)    ! Location of each mirror point for all pitch angles
    integer             :: i_I(1),j_I(1)
    integer             :: iPoint
    real                :: PALossCone
    !----------------------------------------------------------------------------------
    i_I  = minloc(bField_I)
    iMinB= i_I(1)
    bMin = bField_I(iMinB)

    j_I = maxloc(bField_I)
    iMaxB = j_I(1)
    bMax = bField_I(iMaxB)

    PALossCone = asin(sqrt(bField_I(nPoint/2)/bMax))

    if (PitchAngle <= PALossCone) then
       bMirror = bMin/(sin(PALossCone))**2
    else if (PitchAngle == 0.0) then   
       bMirror = bMin/(sin(PitchAngle+cTiny))**2 
    else 
       bMirror = bMin/(sin(PitchAngle))**2 
    end if

    do iPoint = iMinB,1, -1
       if (bField_I(iPoint) >= bMirror ) then 
          iMirror_II(1) = (iPoint + 1)
          EXIT
       end if
    end do

    do iPoint = iMinB, nPoint
       if (bField_I(iPoint) >= bMirror ) then 
          iMirror_II(2) = (iPoint - 1)
          EXIT
       end if
    end do

  end subroutine find_mirror_points

  !==================================================================================

  subroutine second_adiabatic_invariant(nPoint, iMirror_I, bMirror, bField_I, dLength_I,L, SecondAdiabInv)
    !\
    ! Calculate integral of sqrt((B-Bm)/Bm) between the mirror points using the
    ! trapezoidal rule
    !/

    integer             :: nPoint
    integer, intent(in) :: iMirror_I(2)
    real, intent(in)    :: bMirror  
    real, intent(in)    :: dLength_I(nPoint-1)
    real, intent(in)    :: bField_I(nPoint) 
    real, intent(out)   :: SecondAdiabInv
    real, intent(in)    :: L
    real                :: InvL
    integer             :: iPoint, iFirst, iLast
    real                :: DeltaS1, DeltaS2, b1, b2, Coeff
    !----------------------------------------------------------------------------------
    iFirst = iMirror_I(1)
    iLast  = iMirror_I(2)
    SecondAdiabInv = 0.0

    if (iFirst > iLast) RETURN

    InvL = 1.0/L
    Coeff = InvL/sqrt(bMirror)

    DeltaS1 = abs((bMirror-bField_I(iFirst))*(dLength_I(iFirst-1))/(bField_I(iFirst-1)-bField_I(iFirst)))

    SecondAdiabInv= SecondAdiabInv + Coeff*(2./3.)*DeltaS1*sqrt(bMirror-bField_I(iFirst))

    do iPoint = iFirst, iLast-1
       b1 = bField_I(iPoint)
       b2 =  bField_I(iPoint+1)
       SecondAdiabInv = SecondAdiabInv + Coeff*(2./3.)*dLength_I(iPoint)/(b1 - b2) &
            *( sqrt(bMirror  - b2)**3 - sqrt(bMirror  - b1)**3 )  

    end do

    DeltaS2 = abs((bMirror-bField_I(iLast))*(dLength_I(iLast))/(bField_I(iLast+1)-bField_I(iLast)))
    SecondAdiabInv= SecondAdiabInv + Coeff*(2./3.)*DeltaS2*(sqrt(bMirror-bField_I(iLast)))

  end subroutine second_adiabatic_invariant

  !==================================================================================
  subroutine half_bounce_path_length(nPoint, iMirror_I, bMirror, bField_I, dLength_I,L, HalfPathLength,Sb)

    !\
    ! Calculate integral of ds/sqrt((B-Bm)/Bm) between the mirror points using 
    !/

    integer, intent(in) :: nPoint, iMirror_I(2)
    real,    intent(in) :: bMirror, dLength_I(nPoint-1), bField_I(nPoint),L
    real,    intent(out):: HalfPathLength,Sb
    real                :: Inv2L, DeltaS1, DeltaS2,b1,b2, Coeff,CoeffSb
    integer             :: iPoint, iFirst, iLast
    !----------------------------------------------------------------------------------
    iFirst = iMirror_I(1)
    iLast  = iMirror_I(2)
    HalfPathLength = 0.0
    Sb = 0.0

    if (iFirst >iLast) RETURN

    Inv2L = 1.0/(2.*L)
    Coeff = Inv2L*sqrt(bMirror)
    CoeffSb = sqrt(bMirror)

    DeltaS1 = abs((bMirror-bField_I(iFirst))*(dLength_I(iFirst-1))/(bField_I(iFirst-1)-bField_I(iFirst)))
    HalfPathLength = HalfPathLength + Coeff*2.*DeltaS1/(sqrt(bMirror-bField_I(iFirst)))
    Sb = Sb + CoeffSb*2.*DeltaS1/(sqrt(bMirror-bField_I(iFirst)))

    do iPoint = iFirst, iLast-1
       b1 = bField_I(iPoint)
       b2 = bField_I(iPoint+1)

       HalfPathLength = HalfPathLength + Coeff*2.*dLength_I(iPoint)/(b1 - b2) &
            *( sqrt(bMirror  - b2) - sqrt(bMirror  - b1) )
       Sb = Sb + CoeffSb*2.*dLength_I(iPoint)/(b1 - b2) &
            *( sqrt(bMirror  - b2) - sqrt(bMirror  - b1) )

    end do

    DeltaS2 = abs((bMirror-bField_I(iLast))*(dLength_I(iLast))/(bField_I(iLast+1)-bField_I(iLast)))
    HalfPathLength= HalfPathLength + Coeff*2.*DeltaS2/(sqrt(bMirror-bField_I(iLast)))
    Sb = Sb + CoeffSb*2.*DeltaS2/(sqrt(bMirror-bField_I(iLast)))

  end subroutine half_bounce_path_length

  !================================================================================== 
  subroutine get_gradB0(nPoint,nR,nPhi,Phi_I, GradB0x_VIII, GradB0y_VIII, GradB0z_VIII)

    use ModHeidiMain,   ONLY: LZ, Re, DipoleFactor

    implicit none
    integer, intent(in)    :: nPoint        ! Number of points along the field line
    integer, intent(in)    :: nR            ! Number of points in the radial direction
    integer, intent(in)    :: nPhi          ! Number of points in the azimuthal direction
    real,    intent(in)    ::  Phi_I(nPhi) 
    real, dimension(3,nPoint,nR,nPhi), intent(out) :: GradB0x_VIII, GradB0y_VIII, GradB0z_VIII

    !Local Variables
    real    :: LatMax, LatMin,dLat, Lat
    real    :: x, y, z, r, a
    integer :: iPhi, iR, iPoint
    real    :: gradB0xX, gradB0xY, gradB0xZ, gradB0yX, gradB0yY, gradB0yZ
    real    :: gradB0zX, gradB0zY,gradB0zZ
    !----------------------------------------------------------------------------------

    !\
    !Calculates the gradient of B0 components in cartesian coordinates
    !/
    do iPhi =1, nPhi
       do iR =1, nR 
          LatMax =  acos(sqrt(1./LZ(iR)))
          LatMin = -LatMax
          dLat   = (LatMax-LatMin)/(nPoint-1)
          Lat = LatMin
          do iPoint = 1, nPoint

             r = Re*LZ(iR) * (cos(Lat))**2
             x = r * cos(Lat) * cos(Phi_I(iPhi))
             y = r * cos(Lat) * sin(Phi_I(iPhi))
             z = r * sin(Lat)

             a = (sqrt(x**2 + y**2 +z**2))**7

             gradB0xX = -3. * z *(4. * x**2 - y**2 -z**2)/a
             gradB0xY = (-15. * z * x * y)/a
             gradB0xZ = 3. * x *(-4. * z**2 + x**2 + y**2)/a

             gradB0yX = (-15. * z * x * y)/a
             gradB0yY = 3. * z *(-4. * y**2 + x**2 + z**2)/a
             gradB0yZ = 3. * y *(-4. * z**2 + x**2 + y**2)/a

             gradB0zX = 3. * x *(-4. * z**2 + x**2 + y**2)/a
             gradB0zY = 3. * y *(-4. * z**2 + x**2 + y**2)/a
             gradB0zZ = 3. * z *(-2. * z**2 + 3. * x**2 + 3.* y**2)/a

             gradB0x_VIII(1,iPoint,iR,iPhi) = abs(DipoleFactor) * gradB0xX
             gradB0x_VIII(2,iPoint,iR,iPhi) = abs(DipoleFactor) * gradB0xY
             gradB0x_VIII(3,iPoint,iR,iPhi) = abs(DipoleFactor) * gradB0xZ

             gradB0y_VIII(1,iPoint,iR,iPhi) = abs(DipoleFactor) * gradB0yX
             gradB0y_VIII(2,iPoint,iR,iPhi) = abs(DipoleFactor) * gradB0yY             
             gradB0y_VIII(3,iPoint,iR,iPhi) = abs(DipoleFactor) * gradB0yZ

             gradB0z_VIII(1,iPoint,iR,iPhi) = abs(DipoleFactor) * gradB0zX
             gradB0z_VIII(2,iPoint,iR,iPhi) = abs(DipoleFactor) * gradB0zY
             gradB0z_VIII(3,iPoint,iR,iPhi) = abs(DipoleFactor) * gradB0zZ

             Lat = Lat + dLat

          end do
       end do
    end do

  end subroutine get_gradB0
  !================================================================================== 
  real function dipole_length(L, LatMin, LatMax)

    implicit none

    real               :: L                       ! L shell value
    real               :: LatMin                  ! Minimum Latitude
    real               :: LatMax                  ! Maximum Latitude
    real               :: x, y
    !----------------------------------------------------------------------------------

    x = sin(LatMax)
    y = sin(LatMin)

    dipole_length = abs(L*(0.5*Sqrt(3.0*x**2.0+1.0)*x + asinh(sqrt(3.0)*x)/2.0/sqrt(3.0)) &
         - L*(0.5*Sqrt(3.0*y**2.0+1.0)*y + asinh(sqrt(3.0)*y)/2.0/sqrt(3.0))) 

  end function dipole_length

  !==================================================================================

  real function stretched_dipole_length(L,LatMin,LatMax,Phi,alpha,beta)

    use ModHeidiSize, only: nPoint

    implicit none
    real               :: L                       ! L shell value   
    real               :: LatMin                  ! Minimum Latitude                                               
    real               :: LatMax                  ! Maximum Latitude
    real               :: dLat, dSdTheta(nPoint)
    real               :: x(nPoint), y, Phi,Lat
    real               :: alpha, beta              ! Stretching parameters
    integer            :: i
    !----------------------------------------------------------------------------------
    y = cos(Phi)
    stretched_dipole_length = 0.0
    dLat   = (LatMax-LatMin)/(nPoint-1)
    Lat = LatMin

    x(1) = sin(LatMin)

    dSdTheta(1) = (sqrt(-dble((-9.0 * x(1) ** 4 * beta ** 2 + 9.0 * beta ** 2 * &
         x(1) ** 2 + alpha ** 2 + 9.0 * x(1) ** 4 * y ** 2 * beta ** 2 - 9.0 * x(1) ** 4 * y **2 - &
         9.0 * beta ** 2 * y ** 2 * x(1) ** 2 + 9.0 * y ** 2 * x(1) ** 2 - 6.0 * alpha ** 2 * & 
         x(1) ** 2 + 9.0 * x(1) ** 4 * alpha ** 2) * (y ** 2 - y ** 2 * x(1) ** 2 + beta ** 2 - & 
         beta ** 2 * y ** 2 - beta ** 2 * x(1) ** 2 + beta ** 2 * y ** 2 * x(1) ** 2 + &
         alpha ** 2 * x(1) ** 2) ** 2 * (1.0 - x(1) ** 2) * L ** 2 / (-y ** 2 + beta ** 2 * &
         y ** 2 - beta ** 2) / alpha ** 2)))

    do i = 2, nPoint
       Lat = Lat + dLat
       x(i) = sin(Lat)
       dSdTheta(i) = (sqrt(-dble((-9.0 * x(i) ** 4 * beta ** 2 + 9.0 * beta ** 2 * &
            x(i) ** 2 + alpha ** 2 + 9.0 * x(i) ** 4 * y ** 2 * beta ** 2 - 9.0 * x(i) ** 4 * y **2 - &
            9.0 * beta ** 2 * y ** 2 * x(i) ** 2 + 9.0 * y ** 2 * x(i) ** 2 - 6.0 * alpha ** 2 * & 
            x(i) ** 2 + 9.0 * x(i) ** 4 * alpha ** 2) * (y ** 2 - y ** 2 * x(i) ** 2 + beta ** 2 - &
            beta ** 2 * y ** 2 - beta ** 2 * x(i) ** 2 + beta ** 2 * y ** 2 * x(i) ** 2 + &
            alpha ** 2 * x(i) ** 2) ** 2 * (1.0 - x(i) ** 2) * L ** 2 / (-y ** 2 + beta ** 2 * &
            y ** 2 - beta ** 2) / alpha ** 2)))

       stretched_dipole_length = stretched_dipole_length + 0.5*(dSdTheta(i)+dSdTheta(i-1))*dLat

    end do
  end function stretched_dipole_length

  !==================================================================================

  real function asym_stretched_dipole_length(L,LatMin,LatMax,Phi,a,b)

    use ModHeidiSize, only: nPoint

    implicit none
    real               :: L                       ! L shell value   
    real               :: LatMin                  ! Minimum Latitude                                               
    real               :: LatMax                  ! Maximum Latitude
    real               :: dLat, dSdLambda(nPoint)
    real               :: x(nPoint), w(nPoint), y, z, Phi,Lat
    real               :: a, b              ! Stretching parameters
    integer            :: i
    ! Local variables
    real :: t2, t5, t6, t8, t9, t11, t12, t13, t27, t28, t29, t33
    !----------------------------------------------------------------------------------
    y = cos(Phi)
    z = sin(Phi)
    
    asym_stretched_dipole_length = 0.0
    dLat   = (LatMax-LatMin)/(nPoint-1)
    Lat = LatMin

    do i = 1, nPoint
       if ( i == 1 ) Lat = LatMin
       x(i) = sin(Lat)
       w(i) = cos(Lat)
       
       t2 = w(i) ** 2
       t5 = (a + b * y) ** 2
       t6 = y ** 2
       t8 = z ** 2
       t9 = t5 * t6 + t8
       t11 = x(i) ** 2
       t12 = t2 * t9 + t11
       t13 = sqrt(t12)
       t27 = (-0.2D1 * L * w(i) * t13 * x(i) + L * t2 / t13 * (-w(i) * t9 * x(i) + x(i) * w(i))) ** 2
       t28 = L ** 2
       t29 = t2 ** 2
       t33 = sqrt(t27 + t28 * t29 * t12)

       dSdLambda(i) = t33

       Lat = Lat + dLat
    end do

    asym_stretched_dipole_length = asym_stretched_dipole_length + dSdLambda(1)
    do i = 2, nPoint
       asym_stretched_dipole_length = asym_stretched_dipole_length + 0.5*(dSdLambda(i) + dSdLambda(i-1))*dLat
    end do

  end function asym_stretched_dipole_length
  !==================================================================================
  real function asinh(x)              
    
    implicit none

    real, intent(in) :: x
    !----------------------------------------------------------------------------------

    asinh = log(x+sqrt(x**2+1.0))

  end function asinh

  !==================================================================================

  real function second_adiab_invariant(x)

    use ModNumConst, ONLY: cPi

    !\
    ! This is an approximate formula for second adiabatic invariant 
    ! = the integral of sqrt(1 - B/Bm)ds for a dipole B field. 
    !	function I(mu) taken from Ejiri, JGR,1978
    !/

    real, intent(in)     :: x ! cosine of the equatorial pitch angle
    real                 :: y, alpha, beta, a1, a2, a3, a4
    !----------------------------------------------------------------------------------

    y=sqrt(1.-x*x)
    alpha=1.+alog(2.+sqrt(3.))/2./sqrt(3.)
    beta=alpha/2.-cPi*sqrt(2.)/12.
    a1=0.055
    a2=-0.037
    a3=-0.074
    a4=0.056
    second_adiab_invariant = &
         2.*alpha*(1.-y)+2.*beta*y*alog(y)+4.*beta*(y-sqrt(y))+  &
         3.*a1*(y**(1./3.)-y)+6.*a2*(y**(2./3.)-y)+6.*a4*(y-y**(4./3.))  &
         -2.*a3*y*alog(y)

  end function second_adiab_invariant

  !==================================================================================

  real function  analytic_h(x)	
    use ModNumConst, ONLY: cPi
    !\
    ! This is an approximate formula for second adiabatic invariant 
    ! = the integral of ds/sqrt(1 - B/Bm) for a dipole B field. 
    !	function f(y) taken from Ejiri, JGR,1978
    !/

    real, intent(in)     :: x ! cosine of the equatorial pitch angle 
    real                 :: y, alpha, beta, a1, a2, a3, a4

    !----------------------------------------------------------------------------------

    y=sqrt(1-X*X)
    alpha=1.+alog(2.+sqrt(3.))/2./sqrt(3.)
    beta=alpha/2.-cPi*sqrt(2.)/12.
    a1=0.055
    a2=-0.037
    a3=-0.074
    a4=0.056
    analytic_h = alpha-beta*(y+sqrt(y))+a1*y**(1./3.)+a2*y**(2./3.)+  &
         a3*y+a4*y**(4./3.)

  end function analytic_h

  !=====================================================================                      
  subroutine get_quadratic_root(a,b,c,x,nroot)                                                
    !\                                                                                        
    ! Solve the  quadratic equation: ax**2 + bx +c = 0                                        
    !/                                                                                        

    implicit none                                                                             

    real    :: a, b, c            ! coefficients                                              
    real    :: discriminant       ! discriminant                                              
    complex :: x(2)               ! roots                                                     
    integer :: nroot              ! number of roots                                           

    !--------------------------------------------------------------------                     

    if (a == 0.0) then                                                                        
       if(b == 0.0) then                                                                      
          nroot = 0               ! Nothing to solve                                          
       else                                                                                   
          nroot =1                                                                            
          x(1) = cmplx(-c/b, 0.0) ! Linear equation                                           
       end if
    else                                                                                      

       !Start solving the quadratic equation                                                  
       nroot  = 2                                                                             
       discriminant = b*b -4.*a*c                                                             
       if (discriminant >= 0.0) then                                                          
          x(1) = cmplx((-b + sqrt(discriminant))/(2.*a), 0.0)                                 
          x(2) = cmplx((-b - sqrt(discriminant))/(2.*a), 0.0)                                 
       else                                                                                   
          x(1) = cmplx(-b/(2.*a), sqrt(-discriminant)/(2.*a))                                  
          x(2) = cmplx(-b/(2.*a), -sqrt(-discriminant)/(2.*a))                                 
       end if
    end if


  end subroutine get_quadratic_root
  !=====================================================================                      

  subroutine get_cubic_root(a,b,c,d,x,nroot)                                                  

    !\                                                                                        
    ! Solve a cubic equation ax**3 + bx**2 + cx + d = 0                                       
    !/                                                                                        

    use ModNumConst,   ONLY: cPi

    implicit none

    real    :: a,b,c,d       ! coefficients                                                   
    complex :: x(3)          ! roots                                                          
    integer :: nroot         ! number of roots                                                
    real    :: p,q,discriminant                                                               
    real    :: alpha, beta, phi                                                               
    real    :: y1,y2,y3,y2real,y2imag                                                         
    real    :: factor                                                                         
    real    :: u,v                                                                            

    !---------------------------------------------------------------------                      

    y1 = 0.0
    y2 = 0.0
    y3 = 0.0
    y2real = 0.0

    if (a == 0.0) then                                                                        
       call get_quadratic_root(b,c,d,x,nroot)                                                 
       return                                                                                 
    end if

    nroot = 3                                                                                 

    !\                                                                                        
    ! define p and q and the discriminant                                                     
    ! definitions in Tuma and Walsh 'Engineering mathematics handbook'                        
    ! x = y -b/3a ; y**3+py+q = 0                                                             
    ! If discriminant > 0 => one real and two complex roots                                   
    !    discriminant = 0 =>  there are three real roots of which at least two are equal      
    !    discriminant < 0 =>  there are three real unequal roots                              
    !/                                                                                        

    p = (1./3.)*(3.*(c/a)-(b/a)*(b/a))
    q = (1./27.)*(2.*(b/a)*(b/a)*(b/a) - 9.*(b/a)*(c/a) + 27.*(d/a))
    discriminant = (p*p*p)/27. + (q*q)/4.

    if (discriminant < 0.0) then 
       phi = acos((-q/2.)/(sqrt(abs(p*p*p)/ 27.)))
       alpha =  2.* sqrt(abs(p)/3.)                                                           
       y1 = alpha*cos(phi/3.)                                                                 
       y2 = -alpha*cos((phi + cPi)/3.)                                                        
       y3 = -alpha*cos((phi - cPi)/3.)
    else                                                                                      
       alpha = -(q/2.) + sqrt(discriminant)                                                    
       beta  = -(q/2.) - sqrt(discriminant)                                                    
       u = abs(alpha)**(1./3.)                                                                
       v = abs(beta)**(1./3.)                                                                 
       if (alpha < 0.0) u = -u                                                                
       if (beta < 0.0)  v = -v                                                                
       y1 = u + v                                                                             
       y2real = -(u + v)/2.   
       y2imag = (u -v) * sqrt(3.)/2                                                           
    end if

    factor = b/(a*3.)
    y1 = y1 - factor
    y2 = y2 -factor
    y3 = y3 -factor
    y2real = y2real -factor

    if (discriminant < 0.0) then                                                              
       x(1) = cmplx(y1, 0.0)                                                                  
       x(2) = cmplx(y2, 0.0)                                                                  
       x(3) = cmplx(y3, 0.0)                                                                  
    else if (discriminant == 0.0) then                                                             
       x(1) = cmplx(y1, 0.0)                                                                  
       x(2) = cmplx(y2real, 0.0)                                                              
       x(3) = cmplx(y2real, 0.0)                                                              
    else                                                                                      
       x(1) = cmplx(y1, 0.0)                                                                  
       x(2) = cmplx(y2real, y2imag)                                                           
       x(3) = cmplx(y2real, -y2imag)                                                          
    end if


  end subroutine get_cubic_root

  !=================================================================================
  subroutine get_stretched_dipole(L_I, Phi_I, nPoint, nR, nPhi, bFieldMagnitude_III, &
       RadialDistance_III, Length_III, GradBCrossB_VIII,GradB_VIII,dBdt_III)

    use ModHeidiInput,  ONLY: StretchingFactorA,StretchingFactorB
    use ModNumConst,    ONLY: cPi
    use ModHeidiMain,   ONLY: LZ, DipoleFactor


    integer, intent(in)    :: nPoint                              ! Number of points along the field line
    integer, intent(in)    :: nR                                  ! Number of points in the readial direction
    integer, intent(in)    :: nPhi                                ! Number of points in the azimuthal direction
    real,    intent(in)    :: L_I(nR)                             ! L shell value
    real,    intent(in)    :: Phi_I(nPhi)                         ! Phi values
    real,    intent(inout) :: bFieldMagnitude_III(nPoint,nR,nPhi) ! Magnitude of magnetic field 
    real,    intent(out)   :: Length_III(nPoint,nR,nPhi)          ! Length of the field line
    real,    intent(out)   :: RadialDistance_III(nPoint,nR,nPhi)

    !Local Variables    
    real      :: LatMin                              ! Minimum Latitude 
    real      :: LatMax                              ! Maximum Latitude 
    real      :: Lat                                 ! Latitude
    real      :: dLat                                ! Latitude cell size
    real      :: beta2
    real      :: alpha2
    real      :: GradBCrossB_VIII(3,nPoint,nR,nPhi) 
    real      :: GradB_VIII(3,nPoint,nR,nPhi)
    real      :: r,x,y,Vr,Vtheta,Vphi,mag,Br,Btheta,Bphi,GradR, GradTheta, GradPhi
    real      :: a,b,c,gamma
    integer   :: iR, iPhi,iPoint     
    real      :: cos2Lat1
    complex   :: root(3)
    integer   :: nroot, i
    real      :: dd, alpha
    real      :: dBdt_III(nPoint,nR,nPhi), dBdtTemp,p,w
    real      :: beta,t
    !----------------------------------------------------------------------------------
    alpha = StretchingFactorA

    t = 0.0!t/3600.
    w = 2*cPi/50.
    ! Time dependent B field ==> alpha1 = alpha + 1.1*sin(w*t/3600.)
    beta = 1./alpha
    alpha2 = alpha**2
    beta2 = beta**2

    dd = 0.0
    do iPhi =1, nPhi
       y = cos(Phi_I(iPhi))
       ! Calculate the maximum latitude for this case (from the equation of the field line)
       ! Yields a cubic equation in latitude
       gamma = y**2 + beta2 * (1-y**2)
       a = gamma - alpha2
       b = alpha2

       do iR =1, nR 
          c = -1./(LZ(iR)*LZ(iR))
          call get_cubic_root(a,b,dd,c,root,nroot)
          do i =1, nroot
             if ((aimag(root(i)) <= 1.e-5).and. (real(root(i))<=1.0) .and. (real(root(i))>=0.0)) &
                  cos2Lat1 = real(root(i))
          end do

          LatMax = acos(sqrt(cos2Lat1))
          LatMin = -LatMax
          dLat   = (LatMax-LatMin)/(nPoint-1)
          Lat = LatMin

          do iPoint = 1, nPoint
             x = sin(Lat)
             !\
             ! Radial distance for the stretched dipole is calclulated as a function of the 
             ! dipole radial distance; Easy calculation for this case.
             !/

             RadialDistance_III(iPoint,iR,iPhi) = L_I(iR)*(1. - x**2)*&
                  sqrt((1. - x**2) * (y**2 + beta**2 *(1-y**2)) + alpha**2 * x**2)
             r =  RadialDistance_III(iPoint,iR,iPhi)
             
             ! \
             !  Magnetic field components for the uniformly stretched dipole in y and z.
             !/
             Br = -3 * r ** 2 * x * (1 - x ** 2) * y ** 2 * alpha * (r ** 2 * (1 - x ** 2) * &
                  y ** 2 + r ** 2 * (1 - x ** 2) * (1 - y ** 2) * beta ** 2 + r ** 2 * x ** 2 *&
                  alpha ** 2) ** (-0.5D1 / 0.2D1) - 3 * r ** 2 * x * (1 - x ** 2) * (1 - y ** 2) *&
                  alpha * (r ** 2 * (1 - x ** 2) * y ** 2 + r ** 2 * (1 - x ** 2) * (1 - y ** 2) *&
                  beta ** 2 + r ** 2 * x ** 2 * alpha ** 2) ** (-0.5D1 / 0.2D1) + 1 / alpha * &
                  (-2 * r ** 2 * x ** 2 * alpha ** 2 * (r ** 2 * (1 - x ** 2) * y **2 + &
                  r ** 2 * (1 - x ** 2) * (1 - y ** 2) * beta ** 2 + r ** 2 * x** 2 * &
                  alpha ** 2) ** (-0.5D1 / 0.2D1) - (-r ** 2 * (1 - x ** 2) * y ** 2 - &
                  r ** 2 * (1 - x ** 2) * (1 - y ** 2) * beta ** 2) * (r ** 2 * (1 - x ** 2) *&
                  y ** 2 + r ** 2 * (1 - x ** 2) * (1 - y ** 2) * beta ** 2 + r ** 2 * x ** 2 * &
                  alpha ** 2) ** (-0.5D1 / 0.2D1)) * x

             Btheta = -0.3D1 * dble(r ** 2) * dble(x ** 2) * sqrt(dble(1 - x ** 2)) * &
                  dble(y ** 2) * dble(alpha) * dble((r ** 2 * (1 - x ** 2) * y ** 2 + &
                  r ** 2 * (1 - x ** 2) * (1 - y ** 2) * beta ** 2 + r ** 2 * x ** 2 * &
                  alpha ** 2) ** (-0.5D1 / 0.2D1)) - 0.3D1 * dble(r ** 2) *dble(x ** 2) * &
                  sqrt(dble(1 - x ** 2)) * dble(1 - y ** 2) * dble(alpha) * dble((r ** 2 * &
                  (1 - x ** 2) * y ** 2 + r ** 2 * (1 - x ** 2) * (1 - y ** 2) * &
                  beta ** 2 + r ** 2 * x ** 2 * alpha ** 2) ** (-0.5D1 / 0.2D1)) - &
                  0.1D1 / dble(alpha) * dble(-2 * r ** 2 * x ** 2 * alpha ** 2 *&
                  (r ** 2 * (1 - x ** 2) * y ** 2 + r ** 2 * (1 - x ** 2) * (1 - y ** 2) * &
                  beta ** 2 + r ** 2 * x ** 2 * alpha ** 2) ** (-0.5D1 / 0.2D1) -&
                  (-r ** 2 * (1 - x ** 2) * y ** 2 - r ** 2 * (1 - x ** 2) * (1 - y ** 2) *&
                  beta ** 2) * (r ** 2 * (1 - x ** 2) * y ** 2 + r ** 2 * (1 - x ** 2) *&
                  (1 - y ** 2) * beta ** 2 + r ** 2 * x ** 2 * alpha ** 2) ** (-0.5D1 / 0.2D1)) *&
                  sqrt(dble(1 - x ** 2))

             Bphi = 0.0

             !\
             ! Gradient drift components (Vr,Vteta,Vphi)
             !/

             Vr = -0.3D1 / dble(r ** 9) * dble(-1 + x ** 2) * dble(y) * &
                  sqrt(dble(1 - y ** 2)) * dble(-1 + beta ** 2) * dble(-x ** 4 * y ** 4 - 15 &
                  * alpha ** 4 * x ** 2 + 7 * x ** 4 * alpha ** 4 + 2 * y ** 4 * x** 2 + 2 * &
                  beta ** 4 * x ** 2 - beta ** 4 * x ** 4 + 4 * beta ** 2 * x ** 2 * &
                  y ** 2 - y ** 4 * beta ** 4 - 4 * y ** 4 * beta ** 2 * x ** 2 - 6 * &
                  x ** 4 * alpha ** 2 * y ** 2 - 6 * x ** 4 * alpha ** 2 * beta ** 2 - &
                  2 * x ** 4 * y ** 2 * beta ** 2 + 2 * x ** 4 * y** 4 * beta ** 2 - &
                  4 * beta ** 4 * x ** 2 * y ** 2 + 2 * y ** 4 *beta ** 4 * x ** 2 + &
                  2 * beta ** 4 * x ** 4 * y ** 2 - beta ** 4 * x ** 4 * y ** 4 + 2 * &
                  y ** 4 * beta ** 2 + 2 * beta ** 4 * y ** 2 - 2 * y ** 2 * beta ** 2 - &
                  beta ** 4 - y ** 4 - 6 * alpha ** 2 *beta ** 2 * x ** 2 * y ** 2 + &
                  6 * x ** 4 * alpha ** 2 * beta ** 2 * y ** 2 + 6 * alpha ** 2 * &
                  beta ** 2 * x ** 2 + 6 * y ** 2 * alpha ** 2 * x ** 2) / dble((y ** 2 - &
                  x ** 2 * y ** 2 + beta ** 2 - y** 2 * beta ** 2 - beta ** 2 * x ** 2 &
                  + beta ** 2 * x ** 2 * y ** 2 + x ** 2 * alpha ** 2) ** 7) * &
                  dble((r ** 2 * (y ** 2 - x ** 2 * y ** 2 + beta ** 2 - y ** 2 * &
                  beta ** 2 - beta ** 2 * x ** 2 + beta ** 2 * x ** 2 * y ** 2 + &
                  x ** 2 * alpha ** 2)) ** (-0.1D1 / 0.2D1)) / dble(alpha ** 3)

             Vtheta = dble(30 * alpha ** 2 * y ** 4 * beta ** 2 * x ** 6 - 9 * beta ** 4 * alpha ** 2 - &
                  15 * alpha ** 2 * y ** 4 * beta ** 4 * x ** 6 - 99 * x ** 2 * alpha ** 4 * y ** 2 &
                  * beta ** 2 - 30 * alpha ** 2 * y ** 2 * beta ** 2 * x ** 6 + 9 * y ** 6 * beta ** 4 - &
                  6 * alpha ** 2 * y ** 4 * beta ** 2 * x ** 2 + 21 * alpha ** 2 * y ** 4 *beta ** 4 &
                  * x ** 4 + 27 * y ** 6 * beta ** 2 * x ** 2 + 3 * beta ** 6 - 6 * alpha ** 2 * y ** 2 &
                  * beta ** 4 * x ** 2 - 3 * y ** 6 *beta ** 6 - 9 * y ** 6 * beta ** 4 * x ** 6 - &
                  27 * y ** 2 * beta ** 4 * x ** 2 + 39 * alpha ** 4 * beta ** 2 * x ** 6 + &
                  18 * y ** 2* beta ** 4 * alpha ** 2 - 138 * alpha ** 4 * beta ** 2 * x ** 4 + &
                  27 * y ** 2 * beta ** 4 * x ** 4 + 3 * y ** 6 * beta ** 6 * x **6 - 9 * y ** 4 * &
                  beta ** 4 * alpha ** 2 - 9 * y ** 4 * beta ** 2 * x ** 6 + 27 * y ** 4 * beta ** 2 * x ** 4 + &
                  9 * y ** 6 * beta ** 2 * x ** 6 - 42 * alpha ** 2 * y ** 2 * beta ** 4 * x ** 4 + &
                  3 * alpha ** 2 * y ** 4 * beta ** 4 * x ** 2 + 9 * y ** 4 * beta ** 6 - 9 * y ** 2 * &
                  beta ** 6 - 18 * y ** 4 * beta ** 4 - 9 * y ** 6 * beta ** 2 + 108 * x ** 4 * alpha ** 6 - &
                  135 * x ** 2 * alpha ** 6 - 9 * x ** 2 * y ** 6 + 9 * x ** 4 * y ** 6 - 3 * x ** 6 * y ** 6 - &
                  3 * x ** 6 * beta ** 6 + 9 * x ** 4 * beta ** 6 + 9 * y ** 4 * beta ** 2 + 9 * y ** 2 * &
                  beta ** 4 - 9 * x ** 2 * beta ** 6 - 9 * y ** 4 * alpha ** 2 - 21 * alpha ** 6 * x ** 6 - &
                  39 * alpha ** 4 * y ** 2 * beta ** 2 * x ** 6 + 138 * alpha ** 4 * y ** 2 * &
                  beta ** 2 * x ** 4 - 18 * y ** 2 * beta ** 2 * alpha ** 2 + 54 * y ** 4 * beta ** 4 * &
                  x ** 2 + 39 * alpha ** 4 * y ** 2 * x ** 6 - 9 * y ** 4 * beta ** 6 * x ** 6 + &
                  18 * y ** 4 * beta ** 4 * x ** 6 + 27 * y** 4 * beta ** 6 * x ** 4 - 27 * y ** 6 * &
                  beta ** 4 * x ** 2 - 9 * y ** 2 * beta ** 4 * x ** 6 + 3 * alpha ** 2 * y ** 4 * x ** 2 - &
                  138 * alpha ** 4 * y ** 2 * x ** 4 + 27 * y ** 6 * beta ** 4 * x ** 4 + 27 * y ** 2 * &
                  beta ** 6 * x ** 2 + 99 * y ** 2 * x ** 2 * alpha ** 4 - 27 * y ** 4 * beta ** 6 * x ** 2 + &
                  3 * y ** 6 + 42 * beta ** 2 * y ** 2 * x ** 4 * alpha ** 2 - 15 * alpha ** 2 * &
                  beta ** 4 * x ** 6 - 27 * y ** 4 * beta ** 2 * x ** 2 + 99 * x ** 2 * beta ** 2 * &
                  alpha ** 4 + 9 * y ** 2 * beta ** 6 * x ** 6 - 27 * y **2 * beta ** 6 * x ** 4 - &
                  9 * y ** 6 * beta ** 6 * x ** 4 - 27 * y** 6 * beta ** 2 * x ** 4 - 54 * y ** 4 *&
                  beta ** 4 * x ** 4 + 3 * alpha ** 2 * beta ** 4 * x ** 2 + 18 * y ** 4 * &
                  beta ** 2 * alpha ** 2 + 21 * alpha ** 2 * y ** 4 * x ** 4 + 6 * alpha ** 2 * &
                  beta ** 2 * x ** 2 * y ** 2 + 30 * alpha ** 2 * y ** 2 * beta ** 4 * x ** 6 - &
                  42 * alpha ** 2 * y ** 4 * beta ** 2 * x ** 4 + 9 * y ** 6 * beta ** 6 * x ** 2 + &
                  21 * alpha ** 2 * beta ** 4 * x ** 4 - 15 * alpha ** 2 * y ** 4 * x ** 6) * &
                  dble(x) * dble(-1 + beta ** 2) *sqrt(dble(1 - y ** 2)) * dble(y) *&
                  sqrt(dble(1 - x ** 2)) / dble(r ** 9) / dble((y ** 2 - y ** 2 * x ** 2 + beta ** 2 - &
                  beta ** 2 * y ** 2 - beta ** 2 * x ** 2 + beta ** 2 * y ** 2 * x ** 2 + x ** 2 * &
                  alpha ** 2) ** 8) * dble((r ** 2 * (y ** 2 - y ** 2 * x ** 2 + beta ** 2 -&
                  beta ** 2 * y ** 2 - beta ** 2 * x ** 2 + beta ** 2 *y ** 2 * x ** 2 + &
                  x ** 2 * alpha ** 2)) ** (-0.1D1 / 0.2D1)) / dble(alpha ** 3)

             Vphi = dble(144*alpha**2*y**6*beta**2*x**4+72*alpha**2*y**4*beta**2*x**6-3*alpha**4*beta**4*x**6&
                  *y**4-99*x**4*alpha**6*beta**2*y**2+126*x**2*alpha**4*y**4*beta**2+ &
                  72*alpha**2*y**6*beta**4*x**6-144*alpha**2*y**4*beta**4*x**6-126*x**2*alpha**4*y**2*beta**2-9*x**4*y**8+ &
                  36 * y ** 6 * beta ** 4 - 18 * y ** 8 * beta ** 4 + 3 * x ** 6 * y ** 8 + 3 * beta ** 8 * &
                  x ** 6 - 18 * beta** 8 * y ** 4 + 72 * alpha ** 2 * y ** 4 * beta ** 2 * x ** 2 + &
                  288 * alpha ** 2 * y ** 4 * beta ** 4 * x ** 4 + 36 * y ** 6 * beta ** 2 * x ** 2 - &
                  3 * beta ** 8 + 48 * alpha ** 2 * beta ** 6 * x ** 4 * y ** 6 - 72 * alpha ** 2 * &
                  beta ** 6 * x ** 6 * y ** 2 + 72 * alpha ** 2 * y ** 2 * beta ** 4 * x ** 2 + &
                  12 * beta ** 8 * y **2 - 36 * y ** 6 * beta ** 6 - 27 * x ** 2 * alpha ** 6 * &
                  beta ** 2 * y ** 2 - 48 * alpha ** 2 * beta ** 6 * x ** 4 - 3 * alpha ** 4* y ** 4 * &
                  x ** 6 - 78 * alpha ** 6 * y ** 2 * x ** 6 + 18 * y **8 * beta ** 4 * x ** 6 - &
                  36 * y ** 6 * beta ** 4 * x ** 6 - 63 * x ** 2 * alpha ** 4 * beta ** 4 - 78 * alpha ** 6 * &
                  beta ** 2 * x ** 6 + 36 * beta ** 8 * x ** 4 * y ** 2 - 36 * beta ** 8 * x ** 2 * y ** 2 - &
                  12 * beta ** 8 * x ** 6 * y ** 2 + 36 * y ** 6 * beta ** 6 * x ** 6 + 36 * beta ** 8 * &
                  x ** 4 * y ** 6 + 27 * x ** 2 * alpha ** 6 * beta ** 2 + 99 * x ** 4 * alpha ** 6 * &
                  beta ** 2 + 12 *y ** 6 * beta ** 2 * x ** 6 - 144 * alpha ** 2 * y ** 2 * beta **4 * x ** 4 - &
                  144 * alpha ** 2 * y ** 6 * beta ** 4 * x ** 4 + 72 * alpha ** 2 * y ** 6 * beta ** 4 * &
                  x ** 2 - 144 * alpha ** 2 * y ** 4 * beta ** 4 * x ** 2 - 24 * alpha ** 2 * beta ** 6 * &
                  x ** 2 * y ** 6 - 72 * alpha ** 2 * beta ** 6 * x ** 2 * y ** 2 + 9 * x **2 * y ** 8 - &
                  3 * beta ** 8 * y ** 8 + 36 * y ** 4 * beta ** 6 + 144 * alpha ** 2 * beta ** 6 * x ** 4 *&
                  y ** 2 + 72 * alpha ** 2 * beta ** 6 * x ** 2 * y ** 4 - 144 * alpha ** 2 * beta ** 6 *&
                  x**4*y**4-63*x**2*alpha**4*beta**4*y**4+12*y**8*beta**2-12*y**2*beta**6-18*y**4*beta**4-12*y**6*beta**2+ &
                  54*x**6*alpha**8-108*x**4*alpha**8-6*alpha**4*y**2*beta**2*x**6+132*alpha**4*y**2*beta**2*x**4-63*&
                  x**2*alpha**4*y**4+ &
                  3*beta**8*y**8*x**6+54*y**4*beta**4*x**2+27*x**2*alpha**6*y**2+36*y**8*beta**2*x**4+18*beta**8*x**6*y**4- &
                  12*y**8*beta**2*x**6+24*alpha**2*beta**6*x**2+66*alpha**4*y**4*x**4-54*y**8*beta**4*x**4-36*y**4*beta**6*x**6+&
                  18*y**4*beta**4*x**6+108*y**4*beta**6*x**4-108*y**6*beta**4*x**2+24*alpha**2*beta**6*x**6+108*y**6*beta**4* &
                  x**4+36*y**2*beta**6*x**2-108*y**4*beta**6*x**2-3*y**8+9*beta**8*x**2+6*alpha**4*&
                  y**4*beta**2*x**6-132*alpha**4* &
                  y**4*beta**2*x**4-9*beta**8*y**8*x**4+66*alpha**4*beta**4*x**4+54*beta**8*x**2*y**4-48*alpha**2*y**6*x**4- &
                  3*alpha**4*beta**4*x**6+9*beta**8*y**8*x**2+54*y**8*beta**4*x**2+24*alpha**2*y**6*x**6+36*y**8*beta**6*x**4+&
                  12*y**2*beta**6*x**6-36*y**8*beta**6*x**2+99*x**4*alpha**6*y**2-36*y**2*beta**6*x**4-54*beta**8 *&
                  x**4*y**4-108*y**6*beta**6*x**4-36*y**6*beta**2*x**4-54*y**4*beta**4*x**4-12*y**8* beta**6*x**6-36*y**8* &
                  beta**2*x**2-12*beta**8*x**6*y**6+72*alpha**2*beta**6*x**6*y**4+126*x**2*alpha**4*beta**4*y**2+6*alpha**4*&
                  beta**4*x**6*y**2+12*y**8*beta**6+12*beta**8*y**6-9*beta**8*x**4+72*alpha**2*y**2*beta**4*x**6+ &
                  78*alpha**6*beta**2*x**6*y**2-144*alpha**2*y**4*beta**2*x**4+108*y**6*beta**6*x**2+24*alpha**2*y**6*x**2- &
                  36*beta**8*x**2*y**6-72*alpha**2*y**6*beta**2*x**2-24*alpha**2*beta**6*x**6*y**6-132*alpha**4*beta**4*x**4* &
                  y**2-72*alpha**2*y**6*beta**2*x**6+66*alpha**4*beta**4*x**4*y**4)*sqrt(dble(1-x**2))/dble(r**9)/&
                  dble((y**2-y**2*x**2+beta**2-beta**2*y**2-beta**2*x**2+beta**2*y**2*x**2+x**2*alpha**2)**8)*dble((r**2*(y**2- &
                  y**2*x**2+beta**2- beta**2*y**2-beta**2*x**2+beta**2*y**2*x**2+x**2*alpha**2))**(-0.1D1/0.2D1))/dble(alpha**3)

             GradR = 3 * (4 * beta ** 2 * x ** 2 * y ** 2 - beta ** 4 * y ** 4 + 2* beta ** 4 * y ** 2 + &
                  2 * beta ** 4 * x ** 2 + 5 * x ** 4 * alpha ** 4 - 4 * x ** 2 * alpha ** 2 * beta ** 2 *&
                  y ** 2 + 4 * beta ** 2 * x ** 4 * y ** 2 * alpha ** 2 + 2 * beta ** 4 * x ** 2 * &
                  y **4 - 4 * x ** 4 * alpha ** 2 * beta ** 2 + 2 * beta ** 4 * x ** 4 * y ** 2 - &
                  beta ** 4 * x ** 4 * y ** 4 - 4 * beta ** 4 * x ** 2 * y ** 2 + 4 * beta ** 2 * x ** 2 * &
                  alpha ** 2 - beta ** 4 * x ** 4 + 2 * y ** 4 * x ** 2 + 2 * y ** 4 * beta ** 2 - x ** 4 * &
                  y ** 4 - y ** 4 - 2 * beta ** 2 * y ** 2 - beta ** 4 - 9 * alpha ** 4 * x ** 2 + 2 * &
                  x ** 4 * y ** 4 * beta ** 2 - 4 * x ** 4 * y ** 2 * alpha ** 2 - 2 * x ** 4 * beta ** 2 * &
                  y ** 2 - 4 * y ** 4 * beta ** 2 * x ** 2 + 4 * y ** 2 * x ** 2 * alpha ** 2) / &
                  r ** 7 * (-(4 * beta ** 2 * x ** 2 * y ** 2 - beta ** 4 * y ** 4 + 2 * beta ** 4 * &
                  y** 2 + 2 * beta ** 4 * x ** 2 + 5 * x ** 4 * alpha ** 4 - 4 * x ** 2 * alpha ** 2 * beta ** 2 * &
                  y ** 2 + 4 * beta ** 2 * x ** 4 * y ** 2 * alpha ** 2 + 2 * beta ** 4 * x ** 2 * y ** 4 - &
                  4 * x ** 4 * alpha ** 2 * beta ** 2 + 2 * beta ** 4 * x ** 4 * y ** 2 - beta ** 4 * x ** 4 * &
                  y ** 4 - 4 * beta ** 4 * x ** 2 * y ** 2 + 4 * beta ** 2 * x ** 2 * alpha ** 2 - beta ** 4 * &
                  x ** 4 + 2 * y ** 4 * x** 2 + 2 * y ** 4 * beta ** 2 - x ** 4 * y ** 4 - y ** 4 - &
                  2 * beta ** 2 * y ** 2 - beta ** 4 - 9 * alpha ** 4 * x ** 2 + 2 * x ** 4 * y ** 4 * beta ** 2 - &
                  4 * x ** 4 * y ** 2 * alpha ** 2 - 2 * x ** 4 * beta ** 2 * y ** 2 - 4 * y ** 4 * beta ** 2 * &
                  x ** 2 + 4 * y ** 2 * x ** 2 * alpha ** 2) / r ** 6 / alpha ** 2 / (y ** 2 - x ** 2 * y ** 2 + &
                  beta ** 2 - beta ** 2 * y ** 2 - beta ** 2 * x ** 2 + beta ** 2 * x ** 2 * y ** 2 + x ** 2 * &
                  alpha ** 2) ** 5) ** (-0.1D1 / 0.2D1) / (y ** 2 - x ** 2 * y ** 2 + beta ** 2 - beta ** 2 * &
                  y ** 2 - beta ** 2 * x ** 2 + beta ** 2 * x ** 2 * y ** 2 + x ** 2 * alpha ** 2) ** 5 / alpha ** 2

             GradTheta = -0.3D1 * dble(-3 * y ** 4 * alpha ** 2 - 3 * beta ** 4 * alpha ** 2 + 6 * &
                  y ** 4 * alpha ** 2 * beta ** 2 + 14 * x ** 2 * alpha ** 4 * y ** 2 - 6 * y ** 2 * &
                  beta ** 2 * alpha ** 2 - 14 * x ** 2 * alpha ** 4 * beta ** 2 * y ** 2 + beta ** 6 - &
                  3 * beta ** 4 * y ** 4 * alpha ** 2 - 9 * beta ** 2 * x ** 4 * alpha ** 4 - 6 * beta ** 6 * &
                  x ** 2 * y ** 4 + 3 * beta ** 4 * x ** 4 * alpha ** 2 - 3 * beta ** 6 * x ** 4 * y ** 2 + 3 * &
                  beta ** 6 * x ** 4 * y ** 4 + 6 * beta ** 6 * x ** 2 * y ** 2 - 6 * beta ** 4 * y ** 4 + 3 * &
                  beta ** 4 * y ** 2 + beta ** 6 * x ** 4 - beta ** 6 * y ** 6 + 6 * y ** 6 * beta ** 2 * x ** 2 + &
                  2 * y ** 6 * beta ** 6 * x ** 2 + 3 * y ** 4 * alpha ** 2 * x ** 4 + 6 * beta ** 2 * x ** 4 * &
                  y ** 2 *alpha ** 2 + 12 * beta ** 4 * x ** 2 * y ** 4 + 3 * beta ** 4 * x** 4 * y ** 2 - 6 * &
                  beta ** 4 * x ** 4 * y ** 4 - 6 * beta ** 4 *x ** 2 * y ** 2 + 3 * y ** 4 * beta ** 2 + y ** 6 -&
                  y ** 6 * beta** 6 * x ** 4 + 6 * beta ** 4 * alpha ** 2 * y ** 2 + 14 * x ** 2 * alpha ** 4 *&
                  beta ** 2 + 3 * x ** 4 * y ** 4 * beta ** 2 - 6 * y ** 4 * beta ** 2 * x ** 2 + 3 * y ** 6 * &
                  beta ** 4 - 2 * y ** 6 * x ** 2 - 3 * y ** 6 * beta ** 2 - 6 * y ** 4 * beta ** 2 * x ** 4 * &
                  alpha ** 2 - 6 * beta ** 4 * x ** 4 * y ** 2 * alpha ** 2 + 9 * beta ** 2 * y ** 2 * x ** 4 * &
                  alpha ** 4 + 3 * beta ** 4 * y ** 4 * x ** 4 * alpha ** 2 + y ** 6 * x ** 4 + 3 * beta ** 6 * &
                  y ** 4 - 3 * beta ** 6 * y ** 2 - 2 * beta ** 6 * x ** 2 - 9 * y ** 2 * x ** 4 * alpha ** 4 - &
                  6 * y ** 6 * beta ** 4 * x ** 2 + 3 * y ** 6 * beta ** 4 * x ** 4 - 3 * y ** 6 * x ** 4 * &
                  beta ** 2 - 3 * alpha ** 4 * beta ** 2 * y ** 2 + 5 * alpha ** 6 * x ** 4 - 12 * alpha** 6 * &
                  x ** 2 + 3 * alpha ** 4 * y ** 2 + 3 * alpha ** 4 * beta ** 2) / dble(r ** 7) * dble(x) * &
                  sqrt(dble(1 - x ** 2)) / dble(alpha ** 2) / dble((y ** 2 - x ** 2 * y ** 2 + beta ** 2 - &
                  beta ** 2 *y ** 2 - beta ** 2 * x ** 2 + beta ** 2 * x ** 2 * y ** 2 + x ** 2 * alpha ** 2) ** 6) * &
                  dble((-(4 * beta ** 2 * x ** 2 * y ** 2 - beta ** 4 * y ** 4 + 2 * beta ** 4 * y ** 2 + 2 * &
                  beta ** 4 * x **2 + 5 * x ** 4 * alpha ** 4 - 4 * x ** 2 * alpha ** 2 * beta ** 2* y ** 2 + 4 * &
                  beta ** 2 * x ** 4 * y ** 2 * alpha ** 2 + 2 * beta ** 4 * x ** 2 * y ** 4 - 4 * x ** 4 * &
                  alpha ** 2 * beta ** 2 + 2* beta ** 4 * x ** 4 * y ** 2 - beta ** 4 * x ** 4 * y ** 4 - 4 * &
                  beta ** 4 * x ** 2 * y ** 2 + 4 * beta ** 2 * x ** 2 * alpha ** 2 - beta ** 4 * x ** 4 + 2 * &
                  y ** 4 * x ** 2 + 2 * y ** 4 * beta **2 - x ** 4 * y ** 4 - y ** 4 - 2 * beta ** 2 * y ** 2 - &
                  beta ** 4 - 9 * alpha ** 4 * x ** 2 + 2 * x ** 4 * y ** 4 * beta ** 2 - 4 *x ** 4 * y ** 2 * &
                  alpha ** 2 - 2 * x ** 4 * beta ** 2 * y ** 2 - 4 * y ** 4 * beta ** 2 * x ** 2 + 4 * y ** 2 * &
                  x ** 2 * alpha ** 2) / r ** 6 / alpha ** 2 / (y ** 2 - x ** 2 * y ** 2 + beta ** 2 - &
                  beta ** 2 * y ** 2 - beta ** 2 * x ** 2 + beta ** 2 * x ** 2 * y ** 2 + x ** 2 * &
                  alpha ** 2) ** 5) ** (-0.1D1 / 0.2D1))

             GradPhi = 0.3D1 * dble(4 * beta ** 2 * x ** 2 * y ** 2 - beta ** 4 * y** 4 + 2 * beta ** 4 * y ** 2 + &
                  2 * beta ** 4 * x ** 2 + 7 * x **4 * alpha ** 4 - 6 * x ** 2 * alpha ** 2 * beta ** 2 * y ** 2 + &
                  6* beta ** 2 * x ** 4 * y ** 2 * alpha ** 2 + 2 * beta ** 4 * x **2 * y ** 4 - 6 * x ** 4 * &
                  alpha ** 2 * beta ** 2 + 2 * beta ** 4 * x ** 4 * y ** 2 - beta ** 4 * x ** 4 * y ** 4 - 4 * &
                  beta ** 4 * x ** 2 * y ** 2 + 6 * beta ** 2 * x ** 2 * alpha ** 2 - beta ** 4 * x ** 4 + 2 * &
                  y ** 4 * x ** 2 + 2 * y ** 4 * beta ** 2 - x ** 4 *y ** 4 - y ** 4 - 2 * beta ** 2 * y ** 2 - &
                  beta ** 4 - 15 * alpha ** 4 * x ** 2 + 2 * x ** 4 * y ** 4 * beta ** 2 - 6 * x ** 4 * y ** 2 * &
                  alpha ** 2 - 2 * x ** 4 * beta ** 2 * y ** 2 - 4 * y ** 4 *beta ** 2 * x ** 2 + 6 * y ** 2 * &
                  x ** 2 * alpha ** 2) / dble(r ** 7) * dble(-1 + beta ** 2) * sqrt(dble(1 - y ** 2)) * &
                  dble(y) / dble(alpha ** 2) / dble((y ** 2 - x ** 2 * y ** 2 + beta ** 2 - beta ** 2 * y ** 2 - &
                  beta ** 2 * x ** 2 + beta ** 2 * x ** 2 * y ** 2 + x ** 2 * alpha ** 2) ** 6) * &
                  dble((-(4 * beta ** 2 * x ** 2 * y** 2 - beta ** 4 * y ** 4 + 2 * beta ** 4 * y ** 2 + &
                  2 * beta ** 4 * x ** 2 + 5 * x ** 4 * alpha ** 4 - 4 * x ** 2 * alpha ** 2 * beta ** 2 * y ** 2 + &
                  4 * beta ** 2 * x ** 4 * y ** 2 * alpha ** 2 + 2 * beta ** 4 * x ** 2 * y ** 4 - 4 * x ** 4 * &
                  alpha ** 2 * beta ** 2 + 2 * beta ** 4 * x ** 4 * y ** 2 - beta ** 4 * x ** 4 * y **4 - 4 * &
                  beta ** 4 * x ** 2 * y ** 2 + 4 * beta ** 2 * x ** 2 * alpha ** 2 - beta ** 4 * x ** 4 + 2 * &
                  y ** 4 * x ** 2 + 2 * y ** 4 *beta ** 2 - x ** 4 * y ** 4 - y ** 4 - 2 * beta ** 2 * y ** 2 - &
                  beta ** 4 - 9 * alpha ** 4 * x ** 2 + 2 * x ** 4 * y ** 4 * beta **2 - 4 * x ** 4 * y ** 2 * &
                  alpha ** 2 - 2 * x ** 4 * beta ** 2 * y** 2 - 4 * y ** 4 * beta ** 2 * x ** 2 + 4 * y ** 2 * &
                  x ** 2 * alpha ** 2) / r ** 6 / alpha ** 2 / (y ** 2 - x ** 2 * y ** 2 + beta** 2 - &
                  beta ** 2 * y ** 2 - beta ** 2 * x ** 2 + beta ** 2 * x **2 * y ** 2 + x ** 2 * &
                  alpha ** 2) ** 5) ** (-0.1D1 / 0.2D1)) * sqrt(dble(1 - x ** 2))

             ! dB/dt for the stretched dipole

             p = alpha

             dBdtTemp = alpha * cos(w * t) * w * p ** 3 * (0.9D1 * x ** 4 * y ** 6 * p **2 - 0.9D1 * x ** 2 * y ** 6 * p ** 2 &
                  - 0.3D1 * x ** 6 * y ** 6 * p ** 2 + 0.6D1 * x ** 6 * y ** 4 * p ** 2 - 0.96D2 * x ** 4 * y **2 * &
                  p ** 4 + 0.9D1 * x ** 4 * p ** 2 * y ** 2 + 0.60D2 * x ** 4 *p ** 6 * y ** 2 + 0.3D1 * y ** 2 * p ** 2 &
                  - 0.24D2 * x ** 6 * p ** 4 * y ** 4 - 0.3D1 * x ** 6 * p ** 2 * y ** 2 + 0.48D2 * x ** 6 * y ** 2 * &
                  p ** 4 + 0.60D2 * x ** 4 * p ** 8 * y ** 2 - 0.54D2 * x** 2 * p ** 8 * y ** 2 + 0.9D1 * x ** 2 * &
                  p ** 10 * y ** 2 - 0.6D1 * x ** 6 * p ** 8 * y ** 2 + 0.18D2 * x ** 2 * y ** 4 * p ** 2 -0.18D2 * &
                  x ** 4 * y ** 4 * p ** 2 + 0.3D1 * y ** 6 * p ** 6 * x ** 2 + 0.54D2 * x ** 2 * p ** 8 - 0.60D2 * &
                  x ** 4 * p ** 8 - 0.24D2* x ** 2 * p ** 4 + 0.48D2 * x ** 4 * p ** 4 - 0.2D1 * y ** 6 - 0.2D1 * x ** 6 &
                  - 0.6D1 * x ** 2 - 0.60D2 * x ** 4 * p ** 6 * y ** 4+ 0.12D2 * x ** 4 * p ** 8 * y ** 4 + 0.6D1 * &
                  x ** 4 * p ** 10 * y ** 2 + 0.30D2 * x ** 2 * p ** 6 * y ** 4 - 0.6D1 * x ** 2 * p **8 * y ** 4 + &
                  0.30D2 * x ** 6 * p ** 6 * y ** 4 - 0.6D1 * x ** 6 *p ** 8 * y ** 4 - 0.30D2 * x ** 6 * p ** 6 * &
                  y ** 2 - 0.15D2 * x ** 6 * p ** 10 * y ** 2 - 0.6D1 * x ** 4 * y ** 6 + 0.6D1 * x ** 2* y ** 6 - &
                  0.6D1 * x ** 6 * y ** 4 + 0.6D1 * x ** 6 * y ** 2 + 0.2D1 * x ** 6 * y ** 6 - 0.36D2 * x ** 4 * &
                  p ** 12 + 0.6D1 * x ** 6* p ** 8 + 0.20D2 * x ** 6 * p ** 12 + 0.3D1 * y ** 6 * p ** 2 - 0.6D1 * &
                  y ** 2 - 0.3D1 * x ** 4 * y ** 6 * p ** 6 + x ** 6 * y ** 6 * p ** 6 - 0.24D2 * x ** 6 * p ** 4 - &
                  0.1D1 * y ** 6 * p ** 6 + 0.48D2 * x ** 2 * y ** 2 * p ** 4 - 0.6D1 * y ** 4 * p ** 2 - 0.9D1 * &
                  x ** 2 * p ** 2 * y ** 2 - 0.30D2 * x ** 2 * p ** 6 * y ** 2 -0.24D2 * x ** 2 * y ** 4 * p ** 4 + &
                  0.48D2 * x ** 4 * y ** 4 * p ** 4 - 0.18D2 * x ** 2 * y ** 4 + 0.18D2 * x ** 4 * y ** 4 + 0.6D1* &
                  y ** 4 + 0.6D1 * x ** 4 - 0.18D2 * x ** 4 * y ** 2 + 0.18D2 * x** 2 * y ** 2 + 0.2D1) * (-0.1D1 * &
                  (-0.1D1 + 0.4D1 * x ** 4 * y ** 2 * p ** 4 - 0.2D1 * x ** 4 * p ** 2 * y ** 2 - 0.4D1 * x ** 4 *&
                  p ** 6 * y ** 2 - 0.2D1 * y ** 2 * p ** 2 - 0.4D1 * x ** 2 * y **4 * p ** 2 + 0.2D1 * x ** 4 * y ** 4 &
                  * p ** 2 - 0.9D1 * x ** 2 * p ** 8 + 0.5D1 * x ** 4 * p ** 8 - 0.1D1 * y ** 4 * p ** 4 + 0.4D1* &
                  x ** 2 * p ** 4 - 0.4D1 * x ** 4 * p ** 4 + 0.2D1 * x ** 2 + 0.2D1 * y ** 2 - 0.4D1 * x ** 2 * y ** 2 &
                  * p ** 4 + 0.2D1 * y ** 4 *p ** 2 + 0.4D1 * x ** 2 * p ** 2 * y ** 2 + 0.4D1 * x ** 2 * p **6 * y ** 2 &
                  + 0.2D1 * x ** 2 * y ** 4 * p ** 4 - 0.1D1 * x ** 4 * y ** 4 * p ** 4 + 0.2D1 * x ** 2 * y ** 4 - &
                  0.1D1 * x ** 4 * y ** 4 - 0.1D1 * y ** 4 - 0.1D1 * x ** 4 + 0.2D1 * x ** 4 * y ** 2 - 0.4D1 * x ** 2 &
                  * y ** 2) * p ** 4 / r ** 6 / (x ** 2 * y ** 2 - 0.1D1 * x ** 2 * p ** 2 * y ** 2 - 0.1D1 * x ** 2 +&
                  x ** 2 * p ** 4 - 0.1D1 * y ** 2 + y ** 2 * p ** 2 + 0.1D1) ** 5) ** (-0.1D1 / 0.2D1) / r ** 6 / &
                  (x ** 2 * y ** 2 - 0.1D1 * x ** 2 * p ** 2 * y ** 2 -0.1D1 * x ** 2 + x ** 2 * p ** 4 - 0.1D1 * &
                  y ** 2 + y ** 2 * p **2 + 0.1D1) ** 6


             dBdt_III(iPoint,iR,iPhi) = 0.0!dBdtTemp

             mag = abs(DipoleFactor)*(sqrt(Br**2+Btheta**2+Bphi**2))


             ! Gradient B
             GradB_VIII(1,iPoint, iR, iPhi) = abs(DipoleFactor) * GradR
             GradB_VIII(2,iPoint, iR, iPhi) = abs(DipoleFactor) * GradTheta
             GradB_VIII(3,iPoint, iR, iPhi) = abs(DipoleFactor) * GradPhi               

             ! drift Velocity components
             GradBCrossB_VIII(1,iPoint,iR,iPhi) = Vr * (abs(DipoleFactor))**3 
             GradBCrossB_VIII(2,iPoint,iR,iPhi) = 1./(L_I(iR))*Vtheta * (abs(DipoleFactor))**3
             GradBCrossB_VIII(3,iPoint,iR,iPhi) = 1./(L_I(iR)* cos(Lat)) *Vphi * (abs(DipoleFactor))**3 

             bFieldMagnitude_III(iPoint,iR,iPhi) = mag

             Length_III(iPoint,iR,iPhi) = asym_stretched_dipole_length&
                  (L_I(iR), LatMin,Lat,Phi_I(iPhi), StretchingFactorA, StretchingFactorB)  
             Lat = Lat + dLat 

          end do
       end do
    end do


  end subroutine get_stretched_dipole
  !==================================================================================
  subroutine get_analytical_field(L_I, Phi_I, nPoint, nR, nPhi, bFieldMagnitude_III,bField_VIII,&
       RadialDistance_III, Length_III, GradBCrossB_VIII,GradB_VIII,dBdt_III)

    use ModHeidiInput,     ONLY: StretchingFactorA, StretchingFactorB
    use ModCoordTransform, ONLY: rot_xyz_sph
    use ModHeidiMain,      ONLY: LZ, DipoleFactor

    integer, intent(in)    :: nPoint                              ! Number of points along the field line
    integer, intent(in)    :: nR                                  ! Number of points in the readial direction
    integer, intent(in)    :: nPhi                                ! Number of points in the azimuthal direction
    real,    intent(in)    :: L_I(nR)                             ! L shell value
    real,    intent(in)    :: Phi_I(nPhi)                         ! Phi values
    real,    intent(out)   :: bFieldMagnitude_III(nPoint,nR,nPhi) ! Magnitude of magnetic field 
    real,    intent(out)   :: Length_III(nPoint,nR,nPhi)          ! Length of the field line
    real,    intent(out)   :: RadialDistance_III(nPoint,nR,nPhi)
    real,    intent(out)   :: GradBCrossB_VIII(3,nPoint,nR,nPhi) 
    real,    intent(out)   :: GradB_VIII(3,nPoint,nR,nPhi)
    real,    intent(out)   :: dBdt_III(nPoint,nR,nPhi)
    real                   :: bField_VIII(3,nPoint,nR,nPhi)
    !Local Variables    
    real                   :: LatMin, LatMax,dLat,Lat             
    double precision       :: r, x, y, z, Bx, By, Bz, Vx,Vy,Vz, dBdx, dBdy, dBdz
    real                   :: cos2Lat1, alpha, beta
    real                   :: aa, bb, cc, dd, gamma, sigma, a, rad
    real                   :: GradBxyz_D(3),GradBCrossBxyz_D(3),XyzSph_DD(3,3)
    real                   :: GradBSph_D(3),GradBCrossBSph_D(3)
    complex                :: root(3)
    integer                :: nroot, i, iR, iPhi,iPoint 
    real                   :: cos2Lat,sin2Lat,cos2Phi,sin2Phi
    !----------------------------------------------------------------------------------
    alpha = StretchingFactorA
    beta  = StretchingFactorB

    dd = 0.0
    do iPhi =1, nPhi

       sigma = cos(Phi_I(iPhi))
       !\
       ! Calculate the maximum latitude for this case (from the equation of the field line).
       ! Yields a cubic equation in latitude.
       !/
       gamma = sigma**2 + beta**2 * (1-sigma**2)
       bb = alpha**2
       aa = gamma - bb

       do iR =1, nR 
          cc = -1./(LZ(iR)*LZ(iR))
          call get_cubic_root(aa,bb,dd,cc,root,nroot)
          do i =1, nroot
             if ((aimag(root(i)) <= 1.e-5).and. (real(root(i))<=1.0) .and. (real(root(i))>=0.0)) &
                  cos2Lat1 = real(root(i))
          end do

          LatMax = acos(sqrt(cos2Lat1))
          LatMin = -LatMax
          dLat   = (LatMax-LatMin)/(nPoint-1)
          Lat = LatMin

          do iPoint = 1, nPoint
            

             !\
             ! Radial distance for the stretched dipole is calclulated as a function of the 
             ! dipole radial distance; Easy calculation for this case.
             !/

             cos2Lat = (cos(Lat))**2
             sin2Lat = (sin(Lat))**2
             cos2Phi = (cos(Phi_I(iPhi)))**2
             sin2Phi = (sin(Phi_I(iPhi)))**2             

             RadialDistance_III(iPoint,iR,iPhi) = L_I(iR) * cos2Lat *&
                  sqrt( cos2Lat *(cos2Phi + beta**2 * sin2Phi) + alpha**2 *sin2Lat          )
             rad =  RadialDistance_III(iPoint,iR,iPhi)

             x = rad * cos(Lat) * cos(Phi_I(iPhi))
             y = rad * cos(Lat) * sin(Phi_I(iPhi))
             z = rad * sin(Lat)

             r = (x**2 + (beta*y)**2 +(alpha*z)**2)
             a = (sqrt(r))**5
             ! \
             !  Magnetic field components for the uniformly stretched dipole in y and z.
             !/
             Bx = DipoleFactor * (3. * z * x * alpha)/a
             By = DipoleFactor * (3. * z * y * alpha)/a
             Bz = DipoleFactor * (2. * (z*alpha)**2 - x**2 -(y*beta)**2 )/(a * alpha)
             !\
             ! Components of gradient of B in cartesian coordinates.
             !/

             dBdx = abs(DipoleFactor) * (3. * ((4. * z**4 * alpha**4 + 9. * z**2 * x**2 * alpha**4 + 9. * z**2 &
                  * y**2 * alpha**4 - 4. * z**2 * x**2 * alpha**2 - 4. * z**2 * alpha**2  &
                  * y**2 * beta**2 + x**4 + y**4 * beta**4 + 2. * x**2 * y**2 * beta**2)/ &
                  alpha**2/r**5)**(-1./2.) * x * (-12. * z**2 * x**2 * alpha**4 + 3 * z**2&
                  * alpha**4 * y**2 * beta**2 + 3 * z**4 * alpha**6 + 6. * z**2 * x**2 *  &
                  alpha**2 + 6. * z**2 * alpha**2 * y**2 * beta**2 - 8. * z**4 * alpha**4 &
                  - x**4 - 2. * x**2 * y**2 * beta**2 - y**4 * beta**4 - 15. * z**2 * y**2&
                  * alpha**4)/alpha**2/r**6)

             dBdy = abs(DipoleFactor) * (3. * ((4. * z**4 * alpha**4 + 9. * z**2 * x**2 * alpha**4 + 9. * z**2 &
                  * y**2 * alpha**4 - 4. * z**2 * x**2 * alpha**2 - 4. * z**2 * alpha**2  &
                  * y**2 * beta**2 + x**4 + y**4 * beta**4 + 2. * x**2 * y**2 * beta**2)/ &
                  alpha**2/r**5)**(-1./2.) * y * (3. * z**2 * x**2 * alpha**4 - 12. * z**2&
                  * alpha**4 * y**2 * beta**2 + 3. * z**4 * alpha**6 + 6. * z**2 *        &
                  alpha**2 * beta**2 * x**2 + 6. * z**2 * alpha**2 * beta**4 * y**2 - 8. *&
                  z**4 * alpha**4 * beta**2 - 2. * y**2 * beta**4 * x**2 - y**4 * beta**6 &
                  - x**4 * beta**2 - 15. * beta**2 * z**2 * x**2 * alpha**4)/alpha**2/r**6)


             dBdz = abs(DipoleFactor) * (-3. * ((4. * z**4 * alpha**4 + 9 * z**2 * x**2 * alpha**4 + 9. * z**2 &
                  * y**2 * alpha**4 - 4. * z**2 * x**2 * alpha**2 - 4. * z**2 * alpha**2 *&
                  y**2 * beta**2 + x**4 + y**4 * beta**4 + 2. * x**2 * y**2 * beta**2)/   &
                  alpha**2/r**5)**(-1./2.) * z * (-8. * z**2 * x**2 * alpha**2 - 8. * z**2&
                  * alpha**2 * y**2 * beta**2 + 4. * z**4 * alpha**4 - 3. * x**4 *        &
                  alpha**2 - 3. * x**2 * alpha**2 * y**2 * beta**2 + 12. * z**2 * x**2 *  &
                  alpha**4 - 3. * y**2 * alpha**2 * x**2 - 3. * y**4 * alpha**2 * beta**2 &
                  + 12. * z**2 * y**2 * alpha**4 + 3. * x**4 + 6. * x**2 * y**2 * beta**2 &
                  + 3. * y**4 * beta**4)/r**6)

             !\
             ! Gradient drift components (Vx,Vy,Vz = grad(B**2/2.) x B)
             !/

             Vx = (abs(DipoleFactor))**3 *(3. * y * (-21. * z**4 * x**2 * alpha**6 + 6. * z**2 * x**4 * alpha**4 + &
                  18. * z**6 * alpha**8 - 9. * z**2 * alpha**6 * x**4 + 36. * z**4 *      &
                  alpha**8 * x**2 + 36. * z**4 * alpha**8 * y**2 - 9. * z**2 * alpha**6 * &
                  x**2 * y**2 * beta**2 + 27. * z**2 * x**2 * alpha**4 * y**2 * beta**2 - &
                  51. * z**4 * alpha**6 * y**2 * beta**2 + 21. * z**2 * alpha**4 * y**4 * &
                  beta**4 - 9. * z**2 * alpha**6 * y**2 * x**2 - 9. * z**2 * alpha**6 *   &
                  y**4 * beta**2 + x**6 * beta**2 + y**6 * beta**8 - 16. * z**6 * alpha**6&
                  * beta**2 + 3. * x**4 * beta**4 * y**2 + 3. * x**2 * beta**6 * y**4 +20.&
                  * z**4 * alpha**4 * beta**2 * x**2 - 8. * z**2 * alpha**2 * beta**2 *   &
                  x**4 + 20. * z**4 * alpha**4 * beta**4 * y**2 - 8. * z**2 * alpha**2 *  &
                  beta**6 * y**4 - 30. * beta**2 * z**4 * x**2 * alpha**6 + 15. * beta**2 &
                  * z**2 * x**4 * alpha**4 - 16. * z**2 * alpha**2 * beta**4 * x**2 * y**2&
                  + 15. * beta**4 * z**2 * x**2 * alpha** 4. * y**2)/alpha**3 * r**(-17./2.))


             Vy = (abs(DipoleFactor))**3 *(-3. * x * (-51. * z**4 * x**2 * alpha**6 + 21. * z**2 * x**4 * alpha**4 &
                  + 18. * z**6 * alpha**8 - 9. * z**2 * alpha**6 * x**4 + 36. * z**4 *    &
                  alpha**8 * x**2 + 36. * z**4 * alpha**8 * y**2 - 9. * z**2 * alpha**6 * &
                  x**2 * y**2 * beta**2 + 27. * z**2 * x**2 * alpha**4 * y**2 * beta**2 - &
                  21. * z**4 * alpha**6 * y**2 * beta**2 + 6. * z**2 * alpha**4 * y**4 *  &
                  beta**4 + 15. * z**2 * y**2 * alpha**4 * x**2 - 30. * z**4 * y**2 *     &
                  alpha**6 + 15. * z**2 * y**4 * alpha**4 * beta**2 - 16. * x**2 * z**2 * &
                  alpha**2 * y**2 * beta**2 + y**6 * beta**6 - 8. * x**4 * z**2 * alpha**2&
                  + 3. * x**2 * y**4 * beta**4 + 20. * x**2 * z**4 * alpha**4 - 8. * y**4 &
                  * beta**4 * z**2 * alpha**2 + 20. * y**2 * beta**2 * z**4 * alpha**4 +3.&
                  * x**4 * y**2 * beta**2 + x**6 - 16. * z**6 * alpha**6 - 9. * z**2 *    &
                  alpha**6 * y**2 * x**2 - 9. * z**2 * alpha**6 * y**4 * beta**2)/alpha**3&
                  * r**(-17./2.))


             Vz = (abs(DipoleFactor))**3 *(9. * x * z * y * (-15. * z**2 * x**2 * alpha**4 + 15. * z**2 * alpha**4 &
                  * y**2 * beta**2 + 6. * z**2 * x**2 * alpha**2 + 6. * z**2 * alpha**2 * &
                  y**2 * beta**2 - 8. * z**4 * alpha**4 - 2. * x**2 * y**2 * beta**2 -    &
                  y**4 * beta**4 - x**4 - 15. * z**2 * y**2 * alpha**4 - 6. * z**2 *      &
                  alpha**2 * beta**2 * x**2 - 6. * z**2 * alpha**2 * beta**4 * y**2 + 8. *&
                  z**4 * alpha**4 * beta**2 + x**4 * beta**2 + 2. * x**2 * beta**4 * y**2 &
                  + y**4 * beta**6 + 15. * beta**2 * z**2 * x**2 * alpha**4)/alpha * r**(-17./2.))


             dBdt_III(iPoint,iR,iPhi) = 0.0

             ! Magnetic field components in cartesian coordinates
             bField_VIII(1,iPoint,iR,iPhi) = Bx
             bField_VIII(2,iPoint,iR,iPhi) = By
             bField_VIII(3,iPoint,iR,iPhi) = Bz
             !Magnitude of the B field
             bFieldMagnitude_III(iPoint,iR,iPhi) = sqrt(Bx**2 + By**2 + Bz**2)

             ! Convert to spherical coordinates
             XyzSph_DD = rot_xyz_sph(x,y,z)    ! Rotation Matrix from cartesian to spherical
             GradBxyz_D(1) =  dBdx
             GradBxyz_D(2) =  dBdy
             GradBxyz_D(3) =  dBdz

             GradBCrossBxyz_D(1) = Vx
             GradBCrossBxyz_D(2) = Vy
             GradBCrossBxyz_D(3) = Vz

             GradBSph_D       = matmul(GradBxyz_D,       XyzSph_DD)
             GradBCrossBSph_D = matmul(GradBCrossBxyz_D, XyzSph_DD)

             GradB_VIII(1,iPoint, iR, iPhi) = GradBSph_D(1)
             GradB_VIII(2,iPoint, iR, iPhi) = GradBSph_D(2)
             GradB_VIII(3,iPoint, iR, iPhi) = GradBSph_D(3)

             GradBCrossB_VIII(1,iPoint,iR,iPhi) =  GradBCrossBSph_D(1)
             GradBCrossB_VIII(2,iPoint,iR,iPhi) =  GradBCrossBSph_D(2) *  1./(L_I(iR))
             GradBCrossB_VIII(3,iPoint,iR,iPhi) =  GradBCrossBSph_D(3) * 1./(L_I(iR)* cos(Lat))

             Length_III(iPoint,iR,iPhi) = stretched_dipole_length&
                  (L_I(iR), LatMin,Lat,Phi_I(iPhi), StretchingFactorA, StretchingFactorB)  

             Lat = Lat + dLat 

          end do
       end do
    end do

  end subroutine get_analytical_field
  !=========================================================================================
  subroutine get_asym_stretched_field(L_I, Phi_I, nPoint, nR, nPhi, bFieldMagnitude_III,&
       RadialDistance_III, Length_III, GradBCrossB_VIII,GradB_VIII,dBdt_III)

    use ModHeidiInput,     ONLY: StretchingFactorA,StretchingFactorB
    use ModCoordTransform, ONLY: rot_xyz_sph
    use ModHeidiMain,      ONLY: LZ, DipoleFactor
    use get_gradB_components

    integer, intent(in)    :: nPoint                              ! Number of points along the field line
    integer, intent(in)    :: nR                                  ! Number of points in the readial direction
    integer, intent(in)    :: nPhi                                ! Number of points in the azimuthal direction
    real,    intent(in)    :: L_I(nR)                             ! L shell value
    real,    intent(in)    :: Phi_I(nPhi)                         ! Phi values
    real,    intent(out)   :: bFieldMagnitude_III(nPoint,nR,nPhi) ! Magnitude of magnetic field 
    real,    intent(out)   :: Length_III(nPoint,nR,nPhi)          ! Length of the field line
    real,    intent(out)   :: RadialDistance_III(nPoint,nR,nPhi)
    real,    intent(out)   :: GradBCrossB_VIII(3,nPoint,nR,nPhi) 
    real,    intent(out)   :: GradB_VIII(3,nPoint,nR,nPhi)
    real,    intent(out)   :: dBdt_III(nPoint,nR,nPhi)

    !Local Variables    
    real                   :: LatMin, LatMax,dLat,Lat, a, b             
    double precision       :: r, xc, yc, zc, Bx, By, Bz, Vx,Vy,Vz, dBdx, dBdy, dBdz
    real                   :: cos2Lat1
    real                   :: aa, bb, cc, dd, gamma, rad, alpha
    real                   :: GradBxyz_D(3),GradBCrossBxyz_D(3),XyzSph_DD(3,3)
    real                   :: GradBSph_D(3),GradBCrossBSph_D(3)
    complex                :: root(3)
    integer                :: nroot, i, iR, iPhi,iPoint 
    real                   :: cos2Lat,sin2Lat,cos2Phi,sin2Phi

    real, dimension(3)   :: Xyz_D
    real :: CosPhi2, SinPhi2

    !----------------------------------------------------------------------------------

    a = StretchingFactorA
    b = StretchingFactorB

    dd = 0.0
    do iPhi = 1, nPhi
       CosPhi2 = cos(Phi_I(iPhi))**2
       SinPhi2 = sin(Phi_I(iPhi))**2

       alpha = a + b * cos(Phi_I(iPhi)) 

       !\
       ! Calculate the maximum latitude for this case (from the equation of the field line).
       ! Yields a cubic equation in latitude.
       !/

       gamma = alpha**2 * CosPhi2 + SinPhi2 
       aa = gamma - 1.0
       bb = 1.0

       do iR =1, nR 
          cc = -1./(LZ(iR)*LZ(iR))
          call get_cubic_root(aa,bb,dd,cc,root,nroot)
          do i =1, nroot
             if ((aimag(root(i)) <= 1.e-5).and. (real(root(i))<=1.0) .and. (real(root(i))>=0.0)) &
                  cos2Lat1 = real(root(i))
          end do

          LatMax = acos(sqrt(cos2Lat1))
          LatMin = -LatMax
          dLat   = (LatMax-LatMin)/(nPoint-1)
          Lat = LatMin

          do iPoint = 1, nPoint
             !\
             ! Radial distance for the stretched dipole is calclulated as a function of the 
             ! dipole radial distance; Easy calculation for this case.
             !/

             cos2Lat = (cos(Lat))**2
             sin2Lat = (sin(Lat))**2
             cos2Phi = (cos(Phi_I(iPhi)))**2
             sin2Phi = (sin(Phi_I(iPhi)))**2             

             RadialDistance_III(iPoint,iR,iPhi) = L_I(iR) * cos2Lat *&
                  sqrt( cos2Lat *(alpha**2 * cos2Phi + sin2Phi) + sin2Lat)

             rad =  RadialDistance_III(iPoint,iR,iPhi)

             xc = rad * cos(Lat) * cos(Phi_I(iPhi))
             yc = rad * cos(Lat) * sin(Phi_I(iPhi))
             zc = rad * sin(Lat)

             r = sqrt((xc*alpha)**2 + yc**2 + zc**2)  !Radial distance  in cartesian coordinates
             ! \
             !  Magnetic field components for the uniformly stretched dipole in y and z.
             !/
             Bx = (1.0/alpha) * DipoleFactor * (3. * zc * xc * alpha )/r**5 
             By = DipoleFactor * (3. * zc * yc )/r**5
             Bz = DipoleFactor * (2. * zc**2 - (xc* alpha)**2 - yc**2 )/r**5

             !\
             ! Components of gradient of B in cartesian coordinates.
             !/
             call get_dBdx(xc, yc, zc, dBdx)
             call get_dBdy(xc, yc, zc, dBdy)
             call get_dBdz(xc, yc, zc, dBdz)
             !\
             ! Gradient drift components (Vx,Vy,Vz = grad(B**2/2.) x B)
             !/
             call get_GradB2CrossB_x(xc, yc, zc, Vx)
             call get_GradB2CrossB_y(xc, yc, zc, Vy)
             call get_GradB2CrossB_z(xc, yc, zc, Vz)

             dBdt_III(iPoint,iR,iPhi) = 0.0

             !Magnitude of the B field
             bFieldMagnitude_III(iPoint,iR,iPhi) = sqrt(Bx**2 + By**2 + Bz**2)

             Xyz_D(1) = xc
             Xyz_D(2) = yc
             Xyz_D(3) = zc

             ! Convert to spherical coordinates
             XyzSph_DD = rot_xyz_sph(Xyz_D)

             GradBxyz_D(1) =  dBdx
             GradBxyz_D(2) =  dBdy
             GradBxyz_D(3) =  dBdz

             GradBCrossBxyz_D(1) = Vx
             GradBCrossBxyz_D(2) = Vy
             GradBCrossBxyz_D(3) = Vz

             GradBSph_D       = matmul(GradBxyz_D,       XyzSph_DD)
             GradBCrossBSph_D = matmul(GradBCrossBxyz_D, XyzSph_DD)

             GradB_VIII(1,iPoint, iR, iPhi) = GradBSph_D(1)
             GradB_VIII(2,iPoint, iR, iPhi) = GradBSph_D(2)
             GradB_VIII(3,iPoint, iR, iPhi) = GradBSph_D(3)

             GradBCrossB_VIII(1,iPoint,iR,iPhi) =  GradBCrossBSph_D(1) 
             GradBCrossB_VIII(2,iPoint,iR,iPhi) =  GradBCrossBSph_D(2) *  1./(L_I(iR))
             GradBCrossB_VIII(3,iPoint,iR,iPhi) =  GradBCrossBSph_D(3)  * 1./(L_I(iR)* cos(Lat))

             Length_III(iPoint,iR,iPhi) = asym_stretched_dipole_length&
                  (L_I(iR), LatMin,Lat,Phi_I(iPhi), StretchingFactorA, StretchingFactorB)  
             Lat = Lat + dLat

          end do
       end do
    end do

  end subroutine get_asym_stretched_field
  !=========================================================================================
  subroutine test_general_b

    integer, parameter   :: nPoint = 10001
    integer, parameter   :: nR = 1
    integer, parameter   :: nPhi =1
    real                 :: L_I(nR)
    real                 :: Phi_I(nPhi)                         ! Phi values
    real                 :: bFieldMagnitude_III(nPoint,nR,nPhi) ! Magnitude of magnetic field 
    real                 :: RadialDistance_III(nPoint,nR,nPhi)
    real                 :: dLength_III(nPoint-1,nR,nPhi)       ! Length interval between i and i+1  
    real                 :: Length_III(nPoint,nR,nPhi) 
    real                 :: GradBCrossB_VIII(3,nPoint,nR,nPhi),GradB_VIII(3,nPoint,nR,nPhi)
    real                 :: PitchAngle
    real                 :: Ds_I(nPoint)
    real                 :: SecondAdiabInv, IntegralBAnalytic
    real                 :: HalfPathLength, IntegralHAnalytic,Sb
    real                 :: bMirror
    integer              :: iMirror_I(2)
    real, parameter      :: Pi = 3.141592654
    integer              :: iPoint
    real                 :: dBdt_III(nPoint,nR,nPhi)
    !----------------------------------------------------------------------------------
    !open (unit = 2, file = "Convergence_nonuniform.dat")
    !write (2,*)'Numerical values for the second adiabatic invariant integration btw a mirror point and eq'
    !write (2,*)'nPoint  IntegralBAnalytic   2nd_orderB  IntegralHAnalytic  2nd_orderH Percent1, Percent2'

    L_I(1) = 10. 
    Phi_I(1) = 1.0
    PitchAngle = Pi/10.

    do iPoint = 101, nPoint,100
       call initialize_b_field(L_I(1), Phi_I, nPoint, nR, nPhi, bFieldMagnitude_III, &
            RadialDistance_III,Length_III, dLength_III,GradBCrossB_VIII,GradB_VIII,dBdt_III)
       IntegralBAnalytic = second_adiab_invariant(cos(PitchAngle))
       IntegralHAnalytic = analytic_h(cos(PitchAngle))
       call find_mirror_points (iPoint,  PitchAngle, bFieldMagnitude_III, &
            bMirror,iMirror_I)
       call second_adiabatic_invariant(iPoint, iMirror_I, bMirror, bFieldMagnitude_III, Ds_I,L_I(1), SecondAdiabInv)
       call half_bounce_path_length(iPoint, iMirror_I, bMirror,  bFieldMagnitude_III, Ds_I,L_I(1), HalfPathLength,Sb)
    end do

  end subroutine test_general_b
  !==================================================================================

end module ModHeidiBField

