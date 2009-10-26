!\
! Contains the bounced averaged numeric integrals
!/
!==================================================================================

subroutine get_IntegralH(IntegralH_III)

  use ModHeidiSize,  ONLY: nPoint, nPa, nT, nR
  use ModConst,      ONLY: cPi,  cTiny
  use ModHeidiInput, ONLY: TypeBField
  use ModHeidiMain,  ONLY: Phi, LZ, mu
  use ModNumConst,   ONLY: cDegToRad
  use ModHeidiBField
  
  implicit none 

  real :: y,x,alpha,beta,a1,a2,a3,a4

  real                 :: HalfPathLength
  real                 :: bMirror_I(nPa),bMirror
  integer              :: iMirror_II(2,nPa)
  real                 :: Percent, sums, difer
  real                 :: bFieldMagnitude_III(nPoint,nR,nT)! Magnitude of magnetic field 
  real                 :: RadialDistance_III(nPoint,nR,nT)
  real                 :: dLength_III(nPoint-1,nR,nT)      ! Length interval between i and i+1  
  real                 :: Length_III(nPoint,nR,nT) 
  real                 :: PitchAngle_I(nPa)   
  real, intent(out)    :: IntegralH_III(nPa,nR,nT)
  integer              :: iPhi, iR,iPitch
  !----------------------------------------------------------------------------------

  if (TypeBField == 'analytic') then
     alpha=1.+alog(2.+sqrt(3.))/2./sqrt(3.)
     beta=alpha/2.-cPi*sqrt(2.)/12.
     a1=0.055
     a2=-0.037
     a3=-0.074
     a4=0.056

     do iPhi =1 , nT 
        do iR =1, nR    
           do iPitch =1 , nPa
              PitchAngle_I(iPitch) = acos(mu(iPitch))
              !write(*,*) 'iPhi, iR,iPitch,PitchAngle=',iPhi, iR, iPitch,PitchAngle_I(iPitch)
              x = cos(PitchAngle_I(iPitch))
              y=sqrt(1-x*x)
              IntegralH_III(iPitch,iR, iPhi) =alpha-beta*(y+sqrt(y))+ &
                   a1*y**(1./3.)+a2*y**(2./3.)+ a3*y+a4*y**(4./3.)

              !write(*,*) 'IntegralH_III',IntegralH_III(iPitch,iR, iPhi)
              !if (IntegralH_III(iPitch,iR, iPhi)==0.0) then
              !   write(*,*) 'Shit'
              !end if
           end do
        end do
     end do
  endif

  if (TypeBField == 'numeric') then

     call initialize_b_field(LZ, Phi, nPoint, nR, nT, bFieldMagnitude_III, &
          RadialDistance_III,Length_III, dLength_III)

     do iPhi = 1, nT
        do iR =1, nR
           do iPitch =1, nPa
              PitchAngle_I(iPitch) = acos(mu(iPitch))
              call find_mirror_points (nPoint, nPa, PitchAngle_I(iPitch), bFieldMagnitude_III(:,iR,iPhi), &
                   bMirror_I,iMirror_II)

              bMirror = bMirror_I(1)   

              call half_bounce_path_length(nPoint, iMirror_II(:,1),bMirror,&
                   bFieldMagnitude_III(:,iR,iPhi), dLength_III(:,iR,iPhi), LZ(iR), HalfPathLength)

              if (HalfPathLength==0.0) HalfPathLength = cTiny
              IntegralH_III(iPitch, iR, iPhi) = HalfPathLength
           end do
        end do
     end do

  endif

end subroutine get_IntegralH

!============================================================
subroutine get_IntegralI(IntegralI_III)

  use ModHeidiSize,  ONLY: nPoint, nPa, nT, nR
  use ModConst,      ONLY: cPi,  cTiny
  use ModHeidiInput, ONLY: TypeBField
  use ModHeidiMain,  ONLY: Phi, LZ, mu
  use ModHeidiBField
 
  implicit none

  real    :: y,x,alpha,beta,a1,a2,a3,a4
  
  real                 :: SecondAdiabInv
  real                 :: bMirror_I(nPa),bMirror
  integer              :: iMirror_II(2,nPa)
  real                 :: Percent, sums, difer
  real                 :: bFieldMagnitude_III(nPoint,nR,nT) ! Magnitude of magnetic field 
  real                 :: RadialDistance_III(nPoint,nR,nT)
  real                 :: dLength_III(nPoint-1,nR,nT)      ! Length interval between i and i+1  
  real                 :: Length_III(nPoint,nR,nT) 
  real                 :: PitchAngle_I(nPa)
  real, intent(out)    :: IntegralI_III(nPa,nR,nT)
  integer              :: iPhi, iR,iPitch

  !----------------------------------------------------------------------------------

  if (TypeBField == 'analytic') then
     alpha=1.+alog(2.+sqrt(3.))/2./sqrt(3.)
     beta=alpha/2.-cPi*sqrt(2.)/12.
     a1=0.055
     a2=-0.037
     a3=-0.074
     a4=0.056

     do iPhi = 1, nT
        do iR = 1, nR
           do iPitch = 1, nPa
              PitchAngle_I(iPitch) = acos(mu(iPitch))
              write(*,*) 'mu', mu(iPitch)
              if (PitchAngle_I(iPitch)==0.0) PitchAngle_I(iPitch)=cTiny
              x = cos(PitchAngle_I(iPitch))
              
              write(*,*) 'iPitch, PitchAngle_I,x=', iPitch, PitchAngle_I(iPitch), x
              
              y=sqrt(1.-x*x)
              IntegralI_III(iPitch,iR,iPhi)=2.*alpha*(1.-y)+2.*beta*y*alog(y)+4.*beta*(y-sqrt(y))+  &
                   3.*a1*(y**(1./3.)-y)+6.*a2*(y**(2./3.)-y)+6.*a4*(y-y**(4./3.))  &
                   -2.*a3*y*alog(y)
           

           end do
        end do
     end do

  endif



  if (TypeBField == 'numeric') then

     call initialize_b_field(LZ, Phi, nPoint, nR, nT, bFieldMagnitude_III, &
          RadialDistance_III,Length_III, dLength_III)

     do iPhi = 1, nT
        do iR =1, nR
           do iPitch =1, nPa
              PitchAngle_I(iPitch) = acos(mu(iPitch))
              call find_mirror_points (nPoint, nPa, PitchAngle_I(iPitch), bFieldMagnitude_III(:,iR,iPhi), &
                   bMirror_I,iMirror_II)

              bMirror = bMirror_I(1)   

              call second_adiabatic_invariant(nPoint, iMirror_II(:,1), bMirror, &
                   bFieldMagnitude_III(:,iR,iPhi),dLength_III(:,iR,iPhi), LZ(iR), SecondAdiabInv)
              

              if (SecondAdiabInv ==0.0) SecondAdiabInv = cTiny
              IntegralI_III(iPitch,iR,iPhi) = SecondAdiabInv           
           end do
        end do
     end do

  endif


end subroutine get_IntegralI
!============================================================


