!  Copyright (C) 2002 Regents of the University of Michigan, 
!  portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
!\
! Contains the bounced averaged numeric integrals
!/
!==============================================================================

subroutine get_IntegralH(IntegralH_III)

  use ModHeidiSize,  ONLY: nPoint, nPa, lO, nT, nR
  use ModConst,      ONLY: cPi,  cTiny
  use ModHeidiInput, ONLY: TypeBCalc
  use ModHeidiMain,  ONLY: Phi, LZ, mu
  use ModHeidiBField

  implicit none 

  real, intent(out)  :: IntegralH_III(nPa,nR,nT)

  real               :: y,x,alpha,beta,a1,a2,a3,a4
  real               :: HalfPathLength,Sb
  real               :: bMirror_I(nPa),bMirror
  integer            :: iMirror_I(2)
  real               :: bFieldMagnitude_III(nPoint,nR,nT)! Magnitude of magnetic field 
  real               :: RadialDistance_III(nPoint,nR,nT)
  real               :: GradBCrossB_VIII(3,nPoint,nR,nT)
  real               :: GradB_VIII(3,nPoint,nR,nT)
  real               :: dLength_III(nPoint-1,nR,nT)      ! Length interval between i and i+1  
  real               :: Length_III(nPoint,nR,nT) 
  real               :: PitchAngle_I(nPa)   
  integer            :: iPhi, iR,iPitch
  real               :: dBdt_III(nPoint,nR,nT)
  !----------------------------------------------------------------------------
  select case(TypeBCalc)

  case('analytic')
     alpha=1.+alog(2.+sqrt(3.))/2./sqrt(3.)
     beta=alpha/2.-cPi*sqrt(2.)/12.
     a1=0.055
     a2=-0.037
     a3=-0.074
     a4=0.056

     do iPitch =1 , lO
        x = mu(iPitch)
        y = sqrt(1-x**2)
        IntegralH_III(iPitch,:,:) = alpha - beta*(y + sqrt(y))+ &
             a1*y**(1./3.) + a2*y**(2./3.) + a3*y + a4*y**(4./3.)
     end do

  case('numeric')
     write(*,*) 'GET_INTEGRALH======>call initialize_b_field'
     call initialize_b_field(LZ, Phi, nPoint, nR, nT, bFieldMagnitude_III, &
          RadialDistance_III, Length_III, dLength_III,GradBCrossB_VIII, &
          GradB_VIII,dBdt_III)

     do iPhi = 1, nT
        do iR =1, nR
           do iPitch =1, lO
              PitchAngle_I(iPitch) = acos(mu(iPitch))
              call find_mirror_points (&
                   nPoint,  PitchAngle_I(iPitch), bFieldMagnitude_III(:,iR,iPhi), &
                   bMirror_I(iPitch),iMirror_I)
              call half_bounce_path_length(nPoint, iMirror_I(:),bMirror_I(iPitch),&
                   bFieldMagnitude_III(:,iR,iPhi), dLength_III(:,iR,iPhi), &
                   LZ(iR), HalfPathLength,Sb)
              if (HalfPathLength==0.0) HalfPathLength = cTiny
              IntegralH_III(iPitch, iR, iPhi) = HalfPathLength
           end do
        end do
     end do
  
  
  
 ! The h integral is identically zero for the 90 deg pitch angle (equatorilally mirroring particles). 
  IntegralH_III(1,:,:)   = IntegralH_III(1,:,:) + cTiny  
  
  ! At zero deg pitch angle, the H blows up so we extrapolate the value rather than to calculate it.
  do iR = 1, nR
     do iPhi = 1, nT
        IntegralH_III(lo,iR,iPhi) = IntegralH_III(lo-2,iR,iPhi)+ (Length_III(lo,iR,iPhi)-Length_III(lo-2,iR, iPhi))*&
             (IntegralH_III(lo-1,iR,iPhi)-IntegralH_III(lo-2,iR,iPhi))/(Length_III(lo-1,iR,iPhi)-Length_III(lo-2,iR,iPhi))
     end do
  end do
  
end select

  ! Copy the same value in the ghost cell
  IntegralH_III(nPA,:,:) = IntegralH_III(lo,:,:)
  
end subroutine get_IntegralH
!============================================================
subroutine get_IntegralI(IntegralI_III)

  use ModHeidiSize,  ONLY: nPoint, nPa, lo, nT, nR
  use ModConst,      ONLY: cPi,  cTiny
  use ModHeidiInput, ONLY: TypeBCalc
  use ModHeidiMain,  ONLY: Phi, LZ, mu
  use ModHeidiBField

  implicit none

  real, intent(out)    :: IntegralI_III(nPa,nR,nT)

  real                 :: y,x,alpha,beta,a1,a2,a3,a4
  real                 :: SecondAdiabInv
  real                 :: bMirror_I(nPa),bMirror
  integer              :: iMirror_I(2)
  real                 :: bFieldMagnitude_III(nPoint,nR,nT) ! Magnitude of B field 
  real                 :: RadialDistance_III(nPoint,nR,nT)
  real                 :: GradBCrossB_VIII(3,nPoint,nR,nT)
  real                 :: GradB_VIII(3,nPoint,nR,nT)
  real                 :: dLength_III(nPoint-1,nR,nT) ! Length between i and i+1  
  real                 :: Length_III(nPoint,nR,nT) 
  real                 :: PitchAngle_I(nPa)
  integer              :: iPhi, iR,iPitch
  real                 :: dBdt_III(nPoint, nR, nT)
  !----------------------------------------------------------------------------------
  select case(TypeBCalc)
  case('analytic')
     alpha=1.+alog(2.+sqrt(3.))/2./sqrt(3.)
     beta=alpha/2.-cPi*sqrt(2.)/12.
     a1=0.055
     a2=-0.037
     a3=-0.074
     a4=0.056

     do iPitch = 1, lO
        x = mu(iPitch)
        y = max(sqrt(1 - x**2),cTiny)
        IntegralI_III(iPitch,:,:) = &
             2*alpha*(1-y) + 2*beta*y*alog(y) + 4*beta*(y-sqrt(y))+  &
             3*a1*(y**(1./3.)-y) + 6*a2*(y**(2./3.)-y) + 6*a4*(y - y**(4./3.))  &
             - 2*a3*y*alog(y)
     end do

  case('numeric')
     write(*,*) 'GET_INTEGRALI======>call initialize_b_field'
     call initialize_b_field(LZ, Phi, nPoint, nR, nT, bFieldMagnitude_III, &
          RadialDistance_III,Length_III, dLength_III,GradBCrossB_VIII,GradB_VIII,dBdt_III)

     do iPhi = 1, nT
        do iR =1, nR
           do iPitch =1, lO 
              PitchAngle_I(iPitch) = acos(mu(iPitch))
              call find_mirror_points (nPoint,  PitchAngle_I(iPitch), bFieldMagnitude_III(:,iR,iPhi), &
                   bMirror_I(iPitch),iMirror_I)
              call second_adiabatic_invariant(nPoint, iMirror_I(:), bMirror_I(iPitch), &
                   bFieldMagnitude_III(:,iR,iPhi),dLength_III(:,iR,iPhi), LZ(iR), SecondAdiabInv)
              IntegralI_III(iPitch,iR,iPhi) = SecondAdiabInv    
           end do
        end do
     end do

 

  ! The I integral is identically zero for the 90 deg pitch angle (equatorilally mirroring particles). 
  IntegralI_III(1,:,:)   = IntegralI_III(1,:,:) + cTiny  
  
  ! At zero deg pitch angle, the I blows up so we extrapolate the value rather than to calculate it.
  do iR = 1, nR
     do iPhi = 1, nT
        IntegralI_III(lo,iR,iPhi) = IntegralI_III(lo-2,iR,iPhi)+ (Length_III(lo,iR,iPhi)-Length_III(lo-2,iR, iPhi))*&
             (IntegralI_III(lo-1,iR,iPhi)-IntegralI_III(lo-2,iR,iPhi))/(Length_III(lo-1,iR,iPhi)-Length_III(lo-2,iR,iPhi))
     end do
  end do
 
end select

  ! Copy the same value in the ghost cell
  IntegralI_III(nPA,:,:) = IntegralI_III(lo,:,:)
end subroutine get_IntegralI
!===========================================================================
subroutine get_neutral_hydrogen(NeutralHydrogen_III)

  use ModProcHEIDI,  ONLY: iProc
  use ModHeidiSize,  ONLY: nPoint, nPa, lO, nT, nR
  use ModConst,      ONLY: cPi,  cTiny
  use ModHeidiMain,  ONLY: Phi, LZ, mu, T, Re
  use ModHeidiBField
  use ModHeidiHydrogenGeo
  use ModHeidiInput, ONLY: TypeHModel
  use ModIoUnit,     ONLY: UnitTmp_
  use NeutralHydrogenModel
  use ModPlotFile,   ONLY: save_plot_file

  implicit none

  real, intent(out)    :: NeutralHydrogen_III(nR,nT,nPa)

  real                 :: AvgHDensity
  real                 :: bMirror_I(nPa)
  integer              :: iMirror_I(2)
  real                 :: bFieldMagnitude_III(nPoint,nR,nT) ! Magnitude of magnetic field 
  real                 :: RadialDistance_III(nPoint,nR,nT)
  real                 :: GradBCrossB_VIII(3,nPoint,nR,nT)
  real                 :: GradB_VIII(3,nPoint,nR,nT)
  real                 :: dLength_III(nPoint-1,nR,nT)      ! Length interval between i and i+1  
  real                 :: Length_III(nPoint,nR,nT) 
  real                 :: PitchAngle_I(nPa)
  real                 :: Rho_III(nPoint,nR,nT),Rho_I(nPoint)
  integer              :: iPhi, iR,iPitch
  real                 :: HalfPathLength,Sb
  real                 :: dBdt_III(nPoint,nR,nT)


  integer :: iPoint
  !----------------------------------------------------------------------------------
  write(*,*) 'GET_NEUTRAL_HYDROGEN======>call initialize_b_field'

  call initialize_b_field(LZ, Phi, nPoint, nR, nT, bFieldMagnitude_III, &
       RadialDistance_III,Length_III, dLength_III,GradBCrossB_VIII,GradB_VIII,dBdt_III)

  select case(TypeHModel)
  case('Hodges')
     call  get_interpolated_hodge_density(Rho_III)

     do iPitch =1, lO
        PitchAngle_I(iPitch) = acos(mu(iPitch))
        do iPhi = 1, nT
           do iR =1, nR
              call find_mirror_points (nPoint,  PitchAngle_I(iPitch), bFieldMagnitude_III(:,iR,iPhi), &
                   bMirror_I(iPitch),iMirror_I)

              Rho_I = Rho_III(:,iR,iPhi)

              call get_hydrogen_density(nPoint, LZ(iR), bFieldMagnitude_III(:,iR,iPhi), bMirror_I(iPitch)&
                   ,iMirror_I(:),dLength_III(:,iR,iPhi),Rho_I(:),AvgHDensity)

              call half_bounce_path_length(nPoint, iMirror_I(:),bMirror_I(iPitch),&
                   bFieldMagnitude_III(:,iR,iPhi), dLength_III(:,iR,iPhi), LZ(iR), HalfPathLength,Sb)

              if (Sb==0.0) Sb = cTiny
              NeutralHydrogen_III(iR,iPhi,iPitch) = AvgHDensity/Sb

           end do
        end do
     end do

  case('Bailey')
     call  get_bailey_density(Rho_III)

     do iPitch =1, lO
        PitchAngle_I(iPitch) = acos(mu(iPitch))
        do iPhi = 1, nT
           do iR =1, nR
              call find_mirror_points (nPoint,  PitchAngle_I(iPitch), bFieldMagnitude_III(:,iR,iPhi), &
                   bMirror_I(iPitch),iMirror_I)

              Rho_I = Rho_III(:,iR,iPhi)

              call get_hydrogen_density(nPoint, LZ(iR), bFieldMagnitude_III(:,iR,iPhi), bMirror_I(iPitch)&
                   ,iMirror_I(:),dLength_III(:,iR,iPhi),Rho_I(:),AvgHDensity)

              call half_bounce_path_length(nPoint, iMirror_I(:),bMirror_I(iPitch),&
                   bFieldMagnitude_III(:,iR,iPhi), dLength_III(:,iR,iPhi), LZ(iR), HalfPathLength,Sb)

              if (Sb==0.0) Sb = cTiny
              NeutralHydrogen_III(iR,iPhi,iPitch) = AvgHDensity/Sb

           end do
        end do
     end do

  case('twins')
     call  get_TWINS_density(Rho_III)     

     do iPitch =1, lO
        PitchAngle_I(iPitch) = acos(mu(iPitch))
        do iPhi = 1, nT
           do iR =1, nR
              call find_mirror_points (nPoint,  PitchAngle_I(iPitch), bFieldMagnitude_III(:,iR,iPhi), &
                   bMirror_I(iPitch),iMirror_I)

              Rho_I = Rho_III(:,iR,iPhi)

              call get_hydrogen_density(nPoint, LZ(iR), bFieldMagnitude_III(:,iR,iPhi), bMirror_I(iPitch)&
                   ,iMirror_I(:),dLength_III(:,iR,iPhi),Rho_I(:),AvgHDensity)

              call half_bounce_path_length(nPoint, iMirror_I(:),bMirror_I(iPitch),&
                   bFieldMagnitude_III(:,iR,iPhi), dLength_III(:,iR,iPhi), LZ(iR), HalfPathLength,Sb)

              if (Sb==0.0) Sb = cTiny
              NeutralHydrogen_III(iR,iPhi,iPitch) = AvgHDensity/Sb

           end do
        end do
     end do

  case('Ostgaard')
     call  get_ostgaard_density(Rho_III)     

     do iPitch =1, lO
        PitchAngle_I(iPitch) = acos(mu(iPitch))
        do iPhi = 1, nT
           do iR =1, nR
              call find_mirror_points (nPoint,  PitchAngle_I(iPitch), bFieldMagnitude_III(:,iR,iPhi), &
                   bMirror_I(iPitch),iMirror_I)

              Rho_I = Rho_III(:,iR,iPhi)

              call get_hydrogen_density(nPoint, LZ(iR), bFieldMagnitude_III(:,iR,iPhi), bMirror_I(iPitch)&
                   ,iMirror_I(:),dLength_III(:,iR,iPhi),Rho_I(:),AvgHDensity)

              call half_bounce_path_length(nPoint, iMirror_I(:),bMirror_I(iPitch),&
                   bFieldMagnitude_III(:,iR,iPhi), dLength_III(:,iR,iPhi), LZ(iR), HalfPathLength,Sb)

              if (Sb==0.0) Sb = cTiny
              NeutralHydrogen_III(iR,iPhi,iPitch) = AvgHDensity/Sb

           end do
        end do
     end do

  case default

     do iPitch =1, lO
        PitchAngle_I(iPitch) = acos(mu(iPitch))
        do iPhi = 1, nT
           do iR =1, nR
              call find_mirror_points (nPoint,  PitchAngle_I(iPitch), bFieldMagnitude_III(:,iR,iPhi), &
                   bMirror_I(iPitch),iMirror_I)

              call get_observedH_density(nPoint,RadialDistance_III(:,iR,iPhi), LZ(iR), Rho_I, Rho_III)

              do iPoint=1, nPoint
                 Rho_III(iPoint, iR, iPhi) = Rho_I(iPoint)
              end do

              call get_hydrogen_density(nPoint, LZ(iR), bFieldMagnitude_III(:,iR,iPhi), bMirror_I(iPitch)&
                   ,iMirror_I(:),dLength_III(:,iR,iPhi),Rho_I(:),AvgHDensity)

              call half_bounce_path_length(nPoint, iMirror_I(:),bMirror_I(iPitch),&
                   bFieldMagnitude_III(:,iR,iPhi), dLength_III(:,iR,iPhi), LZ(iR), HalfPathLength,Sb)

              if (Sb==0.0) Sb = cTiny
              NeutralHydrogen_III(iR,iPhi,iPitch) = AvgHDensity/Sb
           end do
        end do
     end do

  end select ! TypeHModel

!!! This algorithm does not look correct !!!
  do iPitch = 1, lO; do iPhi = 1, nT; do iR = 1, nR
     NeutralHydrogen_III(iR,iPhi,1) = NeutralHydrogen_III(iR,iPhi,2)
     if (NeutralHydrogen_III(iR,iPhi,iPitch) < 0.0) &
          NeutralHydrogen_III(iR,iPhi,iPitch) = NeutralHydrogen_III(iR,iPhi,iPitch-1)
  end do; end do; end do

  ! Output is written from proc 0 only
  if(iProc/=0) RETURN

  call save_plot_file('HGeo.out', & 
       StringHeaderIn = &
       'Geocoronal hydrogen density in the equatorial plane', &
       NameVarIn = 'R MLT nH', &
       CoordMinIn_D = (/1.75, 0.0/),&
       CoordMaxIn_D = (/6.5, 24.0/),&
       VarIn_VII = Rho_III(51:51,:,:))

  open(unit=UnitTmp_, file=trim(TypeHModel)//'HydrogenDensity.dat', status='unknown')
  do iR = 1, nR
     write(UnitTmp_,*) LZ(iR), Rho_III(51,iR,1)/1.e6
  end do
  close(UnitTmp_)

end subroutine get_neutral_hydrogen
!=============================================================================
subroutine get_B_field(bFieldMagnitude_III)

  ! What's going on here??? What is this subroutine for?
  ! A zillion variables are defined and only one is used??

  use ModHeidiSize,  ONLY: nPoint, nT, nR
  use ModHeidiMain,  ONLY: Phi, LZ,Z
  use ModHeidiBField

  implicit none

  real, intent(out):: bFieldMagnitude_III(nPoint,nR,nT) ! Magnitude of magnetic field 

  real      :: RadialDistance_III(nPoint,nR,nT)
  real      :: dLength_III(nPoint-1,nR,nT)       ! Length interval between i and i+1  
  real      :: GradBCrossB_VIII(3,nPoint,nR,nT)
  real      :: GradB_VIII(3,nPoint,nR,nT)
  real      :: Length_III(nPoint,nR,nT) 
  integer   :: iPhi, iR,iPitch
  real      :: dBdt_III(nPoint,nR,nT)

  !----------------------------------------------------------------------------
  write(*,*) 'GET_B_FIELD======>call initialize_b_field'
  call initialize_b_field(Z, Phi, nPoint, nR, nT, bFieldMagnitude_III, &
       RadialDistance_III,Length_III, dLength_III,GradBCrossB_VIII,GradB_VIII,dBdt_III)

end subroutine get_B_field

!=============================================================================
subroutine get_coef(dEdt_IIII, dMudt_III)

  ! What's the purpose of this subroutine??? Describe!
 
  use ModProcHEIDI,   ONLY: iProc
  use ModHeidiSize,   ONLY: nPoint, iPointBmin_II,iPointEq, nPa, lO, nT, nR, nE, kO
  use ModConst,       ONLY: cTiny  
  use ModHeidiMain,   ONLY: Phi, LZ, mu, EKEV, EBND,Z, funi, funt,dPhi, DipoleFactor
  use ModHeidiDrifts, ONLY: VR, P1,P2
  use ModHeidiInput,  ONLY: TypeBField
  use ModHeidiBField
  use ModHeidiBACoefficients
  use ModNumConst, ONLY: cRadToDeg
  use ModPlotFile, ONLY: save_plot_file

  implicit none

  real, intent(out):: dEdt_IIII(nR,nT,nE,nPA)
  real, intent(out):: dMudt_III(nR,nT,nE,nPA)

  real, dimension(nPa)              :: bMirror_I, PitchAngle_I
  real, dimension(nPoint,nR,nT)     :: bFieldMagnitude_III, RadialDistance_III, Length_III, b4_III
  real, dimension(nPoint)           :: DriftR_I, DriftPhi_I
  real, dimension(3,nPoint,nR,nT)   :: GradBCrossB_VIII, GradB_VIII
  real, dimension(3,nPoint)         :: VDrift_II
  real, dimension(nPoint-1,nR,nT)   :: dLength_III
  real, dimension(nPa,nR,nT)        :: h,s
  real, dimension(nR,nT,nE,nPA)     :: VPhi_IIII,VR_IIII
  real                              :: BouncedDriftR, BouncedDriftPhi
  real                              :: HalfPathLength,Sb,SecondAdiabInv
  integer                           :: iMirror_I(2)
  real                              :: Energy
  real                              :: I2, CoeffE, CoeffMu
  real                              :: InvB, InvR, TermER, TermEPhi1,TermEPhi2,TermEPhi
  real                              :: TermER1, TermER2, TermEB, TermMuB, TermEI
  real                              :: TermMuR, TermMuPhi1,TermMuPhi2,TermMuPhi,TermMut
  real                              :: TermMuR1, TermMuR2,TermMuR3
  real                              :: GradEqBR, GradEqBPhi
  integer                           :: iPhi, iR, iPitch,iE
  real                              :: dBdt_III(nPoint,nR,nT),dIdR_III(nPa,nR,nT),dIdPhi_III(nPa,nR,nT)
  real                              :: dIdt_III(nPa,nR,nT)
  real                              :: BouncedDBdt
  real, dimension(nPoint)           :: TR1, TR2, TPhi
  real                              :: BouncedDriftR1,BouncedDriftR2
  integer                           :: iPoint, iRPlus, iRMinus, iPhiPlus, iPhiMinus
  integer                           :: iPointBmin

  character(LEN=500):: StringVarName, StringHeader, NameFile
  character(len=20) :: TypePosition
  character(len=20) :: TypeFile = 'ascii'  
  !----------------------------------------------------------------------------
  dIdt_III = 0.0

  write(*,*) 'GET_COEF======>call initialize_b_field'
  call initialize_b_field(LZ, Phi, nPoint, nR, nT, bFieldMagnitude_III, &
       RadialDistance_III, Length_III, dLength_III, GradBCrossB_VIII,GradB_VIII,dBdt_III)

  do iPitch = 1, lO
     do iR = 1, nR
        do iPhi = 1, nT
           iRPlus  = min(iR+1, nR)
           iRMinus = max(1,iR-1)
           dIdR_III  (iPitch,iR,iPhi) = (funi(iPitch,iRPlus,iPhi) - funi(iPitch,iRMinus,iPhi))/(LZ(iRPlus)-LZ(iRMinus))

           iPhiPlus  = min(iPhi+1, nT)
           iPhiMinus = max(1,iPhi-1)
           dIdPhi_III(iPitch,iR,iPhi) = (funi(iPitch,iR,iPhiPlus) - funi(iPitch,iR,iPhiMinus))/(Phi(iPhiPlus) - Phi(iPhiMinus))
        end do
     end do
  end do

  do iE = 1, kO
     Energy = 1000. * EKEV(iE)
     do iPhi = 1, nT-1
        do iR = 1, nR
           do iPitch = 1, lO
              PitchAngle_I(iPitch) = acos(mu(iPitch))

              call find_mirror_points (nPoint,  PitchAngle_I(iPitch), bFieldMagnitude_III(:,iR,iPhi), &
                   bMirror_I(iPitch),iMirror_I)
              call half_bounce_path_length(nPoint, iMirror_I(:),bMirror_I(iPitch),&
                   bFieldMagnitude_III(:,iR,iPhi), dLength_III(:,iR,iPhi), LZ(iR), HalfPathLength,Sb)
              call get_drift_velocity(nPoint, Energy,PitchAngle_I(iPitch), bFieldMagnitude_III(:,iR,iPhi),&
                   GradBCrossB_VIII(:,:,iR,iPhi), VDrift_II)

              DriftR_I(:)      = VDrift_II(1,:) ! Radial Drift
              DriftPhi_I(:)    = VDrift_II(3,:) ! Azimuthal Drift

              call get_bounced_drift(nPoint, LZ(iR),bFieldMagnitude_III(:,iR,iPhi),&
                   bMirror_I(iPitch), iMirror_I(:),dLength_III(:,iR,iPhi),&
                   DriftR_I(:),BouncedDriftR,RadialDistance_III(:,iR,iPhi)) 

              call get_bounced_drift(nPoint, LZ(iR),bFieldMagnitude_III(:,iR,iPhi),&
                   bMirror_I(iPitch), iMirror_I(:),dLength_III(:,iR,iPhi),&
                   DriftPhi_I(:),BouncedDriftPhi,RadialDistance_III(:,iR,iPhi)) 

              call get_bounced_drift(nPoint, LZ(iR),bFieldMagnitude_III(:,iR,iPhi),&
                   bMirror_I(iPitch), iMirror_I(:),dLength_III(:,iR,iPhi),&
                   dBdt_III(:,iR,iPhi),BouncedDBdt,RadialDistance_III(:,iR,iPhi)) 

              if (Sb==0.0) Sb = cTiny
              
              if (TypeBField .eq. 'mhd') then
                 iPointBmin = iPointBmin_II(iR,iPhi)
              else
                 iPointBmin = iPointEq
              end if
              
              GradEqBR      = GradB_VIII(1,iPointBMin,iR,iPhi)
              GradEqBPhi    = GradB_VIII(3,iPointBMin,iR,iPhi)
              InvB = 1./bFieldMagnitude_III(iPointBMin,iR,iPhi)
              InvR =  1./LZ(iR)

              !\
              ! dE/dt bounce average coefficient
              !/

              CoeffE = EBND(iE)* InvB *(1. -  funi(iPitch,iR,iPhi)/(2.* funt(iPitch,iR,iPhi)))

              TermEB  = CoeffE * dBdt_III(iPointBMin,iR,iPhi)
              TermER1 = CoeffE * GradEqBR * VR(iR,iPhi,iE,iPitch)
              TermER2 = - (EBND(iE)/(funt(iPitch,iR,iPhi))) * VR(iR,iPhi,iE,iPitch) *&
                   (InvR * funi(iPitch,iR,iPhi) + dIdR_III(iPitch,iR,iPhi)) 
              TermER  = TermER1 + TermER2

              TermEPhi1 = CoeffE * GradEqBPhi* (P1(iR,iPhi) + P2(iR,iPhi,iE,iPitch))
              TermEPhi2 = - (EBND(iE)/(funt(iPitch,iR,iPhi)))* &
                   (P1(iR,iPhi) + P2(iR,iPhi,iE,iPitch)) * dIdPhi_III(iPitch,iR,iPhi)
              TermEPhi = TermEPhi1 + TermEPhi2
              TermEI    = (EBND(iE)/(funt(iPitch,iR,iPhi))) * dIdt_III(iPitch,iR,iPhi)

              dEdt_IIII(iR,iPhi,iE,iPitch)  = TermEB + TermER + TermEPhi + TermEI

              !\
              !  dMu/dT bounce averaged coefficient 
              !/

              CoeffMu = -(funi(iPitch,iR,iPhi)/(2.* funt(iPitch,iR,iPhi)))
              dBdt_III(iPointBMin,iR,iPhi) = 0.0
              dIdt_III(iPitch,iR,iPhi)   = 0.0

              TermMut      = 0.5 * InvB * dBdt_III(iPointBmin,iR,iPhi) + &
                   dIdt_III(iPitch,iR,iPhi)/funi(iPitch,iR,iPhi) 
              TermMuR1     = InvR 
              TermMuR2     = 0.5 * InvB * GradEqBR 
              TermMuR3     = dIdR_III(iPitch,iR,iPhi)/funi(iPitch,iR,iPhi) 
            
              TermMuR      = (TermMuR1 + TermMuR2 + TermMuR3) * VR(iR,iPhi,iE,iPitch)
              
              TermMuPhi1 = 0.5 * InvB * GradEqBPhi 
              TermMuPhi2 = dIdPhi_III(iPitch,iR,iPhi)/funi(iPitch,iR,iPhi) 
              TermMuPhi = (TermMuPhi1 + TermMuPhi2)*(P1(iR,iPhi) + P2(iR,iPhi,iE,iPitch))

              dMudt_III(iR,iPhi,iE,iPitch) =  CoeffMu*(TermMut + TermMuR + TermMuPhi)
           end do
           dEdt_IIII(iR,iPhi,iE,1) = dEdt_IIII(iR,iPhi,iE,2) 
           dMudt_III(iR,iPhi,iE,1) = dMudt_III(iR,iPhi,iE,2)
        end do
     end do
  end do

  ! Only root proc should write the various files below (?)
  if(iProc /= 0) RETURN

  StringHeader = 'EDOT values'
  StringVarName = 'R MLT Edot E PA NR NT'
  TypePosition = 'rewind'
  iE = 37

  NameFile = 'EDOT88.out'
  iPitch = 2
  call save_plot_file(NameFile, &
       TypePositionIn = TypePosition,&
       TypeFileIn     = TypeFile,&
       StringHeaderIn = StringHeader, &
       ParamIn_I = (/ EKEV(iE), cRadToDeg*acos(mu(iPitch)), &
       real(nR), real(NT-1)/), & 
       NameVarIn = StringVarName, &
       CoordMinIn_D = (/1.75, 0.0/),&
       CoordMaxIn_D = (/6.5, 23.0/),&
       VarIn_IIV = dEdt_IIII(:,1:24,iE,iPitch:iPitch))

  NameFile = 'EDOT60.out'
  iPitch = 20
  call save_plot_file(NameFile, &
       TypePositionIn = TypePosition,&
       TypeFileIn     = TypeFile,&
       StringHeaderIn = StringHeader, &
       ParamIn_I = (/ EKEV(iE), cRadToDeg*acos(mu(iPitch)), &
       real(nR), real(NT-1)/), & 
       NameVarIn = StringVarName, &
       CoordMinIn_D = (/1.75, 0.0/),&
       CoordMaxIn_D = (/6.5, 23.0/),&
       VarIn_IIV = dEdt_IIII(:,1:24,iE,iPitch:iPitch))

  NameFile = 'EDOT30.out'
  iPitch = 42
  call save_plot_file(NameFile, &
       TypePositionIn = TypePosition,&
       TypeFileIn     = TypeFile,&
       StringHeaderIn = StringHeader, &
       ParamIn_I = (/ EKEV(iE), cRadToDeg*acos(mu(iPitch)), &
       real(nR), real(NT-1)/), & 
       NameVarIn = StringVarName, &
       CoordMinIn_D = (/1.75, 0.0/),&
       CoordMaxIn_D = (/6.5, 23.0/),&
       VarIn_IIV = dEdt_IIII(:,1:24,iE,iPitch:iPitch))

  NameFile = 'MUDOT88.out'
  StringHeader = 'MUDOT values'
  StringVarName = 'R MLT Mudot E PA NR NT'
  TypePosition = 'rewind'
  iE = 37
  iPitch = 2
  call save_plot_file(NameFile, &   
       TypePositionIn = TypePosition,& 
       TypeFileIn     = TypeFile,&   
       StringHeaderIn = StringHeader, &   
       ParamIn_I = (/ EKEV(iE), cRadToDeg*acos(mu(iPitch)), &
       real(nR), real(NT-1)/), & 
       NameVarIn = StringVarName, &
       CoordMinIn_D = (/1.75, 0.0/),& 
       CoordMaxIn_D = (/6.5, 23.0/),&
       VarIn_IIV = dMudt_III(:,1:24,iE,iPitch:iPitch)) 

  NameFile = 'MUDOT60.out'
  iPitch = 20
  call save_plot_file(NameFile, &   
       TypePositionIn = TypePosition,& 
       TypeFileIn     = TypeFile,&   
       StringHeaderIn = StringHeader, &   
       ParamIn_I = (/ EKEV(iE), cRadToDeg*acos(mu(iPitch)), &
       real(nR), real(NT-1)/), & 
       NameVarIn = StringVarName, &
       CoordMinIn_D = (/1.75, 0.0/),& 
       CoordMaxIn_D = (/6.5, 23.0/),&
       VarIn_IIV = dMudt_III(:,1:24,iE,iPitch:iPitch)) 

  NameFile = 'MUDOT30.out'
  iPitch = 42
  call save_plot_file(NameFile, &   
       TypePositionIn = TypePosition,& 
       TypeFileIn     = TypeFile,&   
       StringHeaderIn = StringHeader, &   
       ParamIn_I = (/ EKEV(iE), cRadToDeg*acos(mu(iPitch)), &
       real(nR), real(NT-1)/), & 
       NameVarIn = StringVarName, &
       CoordMinIn_D = (/1.75, 0.0/),& 
       CoordMaxIn_D = (/6.5, 23.0/),&
       VarIn_IIV = dMudt_III(:,1:24,iE,iPitch:iPitch)) 

end subroutine get_coef

!============================================================

subroutine get_grad_curv_drift(VPhi_IIII,VR_IIII)

  use ModHeidiSize,   ONLY: nPoint, nPa, lO, nT, nR, nE, kO, dt
  use ModConst,       ONLY: cTiny  
  use ModHeidiMain,   ONLY: Phi, LZ, mu, EKEV, EBND, wmu, DPHI, Z, Re, DipoleFactor, t 
  use ModHeidiDrifts, ONLY: VrConv, P1,P2
  use ModHeidiBField
  use ModHeidiBACoefficients

  implicit none

  real, dimension(nPa)              :: bMirror_I, PitchAngle_I
  real, dimension(nPoint,nR,nT)     :: bFieldMagnitude_III, RadialDistance_III, Length_III, b4_III
  real, dimension(nPoint)           :: DriftR_I, DriftPhi_I
  real, dimension(3,nPoint,nR,nT)   :: GradBCrossB_VIII, GradB_VIII
  real, dimension(3,nPoint)         :: VDrift_II
  real, dimension(nPoint-1,nR,nT)   :: dLength_III
  real, dimension(nPa,nR,nT)        :: h,s
  real, dimension(nR,nT,nE,nPA)     :: VPhi_IIII,VR_IIII
  real                              :: BouncedDriftR, BouncedDriftPhi
  real                              :: HalfPathLength,Sb,SecondAdiabInv
  integer                           :: iMirror_I(2)
  real                              :: Energy
  real                              :: I2, CoeffE, CoeffMu
  real                              :: InvB, InvR, TermER, TermEPhi
  real                              :: TermER1, TermER2
  real                              :: TermMuR, TermMuPhi
  real                              :: TermMuR1, TermMuR2
  real                              :: GradEqBR, GradEqBPhi
  integer                           :: iPhi, iR, iPitch,iE, iPoint
  real                              :: dBdt_III(nPoint,nR,nT)

  !----------------------------------------------------------------------------

  write(*,*) 'GET_GRAD_CURV_DRIFT======>call initialize_b_field'
  call initialize_b_field(Z, Phi, nPoint, nR, nT, bFieldMagnitude_III, &
       RadialDistance_III, Length_III, dLength_III, GradBCrossB_VIII,GradB_VIII,dBdt_III)

  do iE = 1, kO
     Energy = 1000. * EKEV(iE)
     do iPhi = 1, nT
        do iR = 1, nR
           do iPitch = 1, lO
              PitchAngle_I(iPitch) = acos(mu(iPitch))

              call find_mirror_points (nPoint,  PitchAngle_I(iPitch), bFieldMagnitude_III(:,iR,iPhi), &
                   bMirror_I(iPitch),iMirror_I)
              call half_bounce_path_length(nPoint, iMirror_I(:),bMirror_I(iPitch),&
                   bFieldMagnitude_III(:,iR,iPhi), dLength_III(:,iR,iPhi), Z(iR), HalfPathLength,Sb)
              call get_drift_velocity(nPoint, Energy,PitchAngle_I(iPitch), bFieldMagnitude_III(:,iR,iPhi),&
                   GradBCrossB_VIII(:,:,iR,iPhi), VDrift_II)
              DriftR_I(:)      = VDrift_II(1,:) ! Radial Drift
              DriftPhi_I(:)    = VDrift_II(3,:) ! Azimuthal Drift
              call get_bounced_drift(nPoint, Z(iR),bFieldMagnitude_III(:,iR,iPhi),&
                   bMirror_I(iPitch), iMirror_I(:),dLength_III(:,iR,iPhi),&
                   DriftR_I(:),BouncedDriftR,RadialDistance_III(:,iR,iPhi)) 
              call get_bounced_drift(nPoint, Z(iR),bFieldMagnitude_III(:,iR,iPhi),&
                   bMirror_I(iPitch), iMirror_I(:),dLength_III(:,iR,iPhi),&
                   DriftPhi_I(:),BouncedDriftPhi,RadialDistance_III(:,iR,iPhi)) 
              if (Sb==0.0) Sb = cTiny
              VR_IIII(iR,iPhi,iE,iPitch) = BouncedDriftR/Sb/Re
              VPhi_IIII(iR,iPhi,iE,iPitch) = BouncedDriftPhi/Sb
           end do
           VR_IIII(iR,iPhi,iE,1)      = VR_IIII(iR,iPhi,iE,2) 
           VPhi_IIII(iR,iPhi,iE,1)    = VPhi_IIII(iR,iPhi,iE,2)
        end do
     end do
  end do
  
  
  
  !!\ This is just for testing---REMOVE!!!
!!$  
!!$ 
!!$     open(unit=33, file='test_debug_integrals.dat')
!!$     write(*,*) 'SimulationTime = ',  T, ': I am in the loop'
!!$     write(33,*) 'iPoint LZ En phi VPhi P2 VrConv VRVrConv B ds R GradBCrossBx GradBCrossBy GradBCrossBz'
!!$     do iR =20,20!nR
!!$        do iPhi = 2,2!nT
!!$           do iE =3, 3
!!$              do iPitch =71, 71
!!$                 do iPoint =1, nPoint
!!$                    
!!$                    write(33,'(1I5, 13E11.3)') iPoint, LZ(iR),  1000. * EKEV(iE), acos(mu(iPitch)),&
!!$                         VPhi_IIII(iR,iPhi,iE,iPitch), P2(iR,iPhi,iE,iPitch),&
!!$                         VrConv(iR,iPhi,iE,iPitch), VR_IIII(iR,iPhi,iE,iPitch)+VrConv(iR,iPhi,iE,iPitch), &
!!$                         bFieldMagnitude_III(iPoint,iR,iPhi), dLength_III(iPoint,iR,iPhi), &
!!$                         RadialDistance_III(iPoint,iR,iPhi),  GradBCrossB_VIII(1,iPoint,iR,iPhi),  &
!!$                         GradBCrossB_VIII(2,iPoint,iR,iPhi),  GradBCrossB_VIII(3,iPoint,iR,iPhi)
!!$                 end do
!!$              end do
!!$           end do
!!$        end do
!!$     end do
!!$     close(33)



!!$   open(unit=3, file='DriftVsPA.dat')
!!$ 
!!$   do iR =14,14
!!$      do iPhi = 1,nT
!!$         do iE =37, 37
!!$            do iPitch =1, lO
!!$               write(3,*)  VPhi_IIII(iR,iPhi,iE,iPitch),P2(iR,iPhi,iE,iPitch),VrConv(iR,iPhi,iE,iPitch),&
!!$                    VR_IIII(iR,iPhi,iE,iPitch)+VrConv(iR,iPhi,iE,iPitch),&
!!$                    iR,iPhi,iE,iPitch, acos(mu(iPitch))
!!$            end do
!!$         end do
!!$      end do
!!$   end do
!!$   close(3)
!!$
!!$   open(unit=3, file='DriftVsL.dat')
!!$  
!!$      do iPhi =1, nT
!!$         do iE =37, 37
!!$            do iPitch =2, 2
!!$               do iR =1, nR
!!$  
!!$               write(3,*)  VPhi_IIII(iR,iPhi,iE,iPitch),P2(iR,iPhi,iE,iPitch),VrConv(iR,iPhi,iE,iPitch),&
!!$                    VR_IIII(iR,iPhi,iE,iPitch)+VrConv(iR,iPhi,iE,iPitch),&
!!$                   iR,iPhi,iE,iPitch, LZ(iR)
!!$               
!!$  
!!$            end do
!!$         end do
!!$      end do
!!$   end do
!!$  
!!$   close(3)
!!$
!!$  open(unit=3, file='DriftVsPhi.dat')
!!$  write(3,*) 'drifts'
!!$  write(3,*) 'VPhi_IIII       P2       P1   VrConv   VR_IIII+VrConv           Phi'
!!$  
!!$   do iR =14, 14
!!$      do iPhi =1, nT
!!$         do iE =37, 37
!!$            do iPitch =5, 5
!!$               write(3,*)  VPhi_IIII(iR,iPhi,iE,iPitch),P2(iR,iPhi,iE,iPitch),P1(iR,iPhi),&
!!$                    VrConv(iR,iPhi,iE,iPitch),&
!!$                    VR_IIII(iR,iPhi,iE,iPitch)+VrConv(iR,iPhi,iE,iPitch),&
!!$                   Phi(iPhi)
!!$  
!!$            end do
!!$         end do
!!$      end do
!!$   end do
!!$   close(3)




end subroutine get_grad_curv_drift
