!  Copyright (C) 2002 Regents of the University of Michigan, portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
module ModHeidiBACoefficients

  implicit none

contains
  !===============================================================
  subroutine get_drift_velocity(nPoint,Energy,PitchAngle,&
       bFieldMagnitude_I,GradBCrossB_II,VDrift_II)
    ! \ 
    !   This subroutine calculates the drift velocity components
    ! /

    integer, intent(in)    :: nPoint
    real,    intent(in)    :: Energy
    real,    intent(in)    :: PitchAngle
    real,    intent(in)    :: bFieldMagnitude_I(nPoint)
    real,    intent(in)    :: GradBCrossB_II(3,nPoint)
    real,    intent(out)   :: VDrift_II(3,nPoint)
    real                   :: b2,b4,sinPitch,sin2Pitch, Coeff
    integer                :: iPoint
    !-----------------------------------------------------------------------------

    do iPoint =1 ,nPoint

       b2 = bFieldMagnitude_I(iPoint)*bFieldMagnitude_I(iPoint)
       b4 = b2*b2
       sinPitch = sin(PitchAngle)
       sin2Pitch = sinPitch*sinPitch
       Coeff = -Energy*(2.-sin2Pitch)/b4
       !dR/dt
       VDrift_II(1,iPoint) = Coeff*GradBCrossB_II(1,iPoint)
       ! dTheta/dt                       
       VDrift_II(2,iPoint) = Coeff*GradBCrossB_II(2,iPoint)   
       ! dPhi/dt
       VDrift_II(3,iPoint) = Coeff*GradBCrossB_II(3,iPoint)  

    end do

  end subroutine get_drift_velocity

  !===============================================================

  subroutine get_bounced_drift(nPoint, L, bField_I, bMirror,iMirror_I,&
       dLength_I,Drift_I,BouncedDrift,RadialDistance_I)

    integer, intent(in)  :: nPoint
    real,    intent(in)  :: L
    real,    intent(in)  :: bField_I(nPoint) 
    real,    intent(in)  :: bMirror  
    integer, intent(in)  :: iMirror_I(2)
    real,    intent(in)  :: dLength_I(nPoint-1)
    real,    intent(in)  :: Drift_I(nPoint)
    real,    intent(in)  :: RadialDistance_I(nPoint)
    real,    intent(out) :: BouncedDrift
    real                 :: DeltaS1, DeltaS2, b1, b2, Coeff
    integer              :: iPoint, iFirst, iLast

    !-----------------------------------------------------------------------------

    iFirst = iMirror_I(1)
    iLast  = iMirror_I(2)

    BouncedDrift    = 0.0

    if (iFirst > iLast) RETURN


    Coeff = sqrt(bMirror) 
    DeltaS1 = abs((bMirror-bField_I(iFirst))*&
         (dLength_I(iFirst-1))/(bField_I(iFirst-1)-bField_I(iFirst)))

    BouncedDrift    = BouncedDrift + Drift_I(iFirst)*Coeff*2.*DeltaS1/(sqrt(bMirror-bField_I(iFirst)))
    do iPoint = iFirst, iLast-1
       b1 = bField_I(iPoint)
       b2 = bField_I(iPoint+1)
       BouncedDrift =  BouncedDrift + Drift_I(iPoint)*Coeff*2.*dLength_I(iPoint)/(b1 - b2) &
            *( sqrt(bMirror  - b2) - sqrt(bMirror  - b1) )
    end do

    DeltaS2 = abs((bMirror-bField_I(iLast))*(dLength_I(iLast))/(bField_I(iLast+1)-bField_I(iLast)))
    BouncedDrift  = BouncedDrift + Drift_I(iLast)* Coeff*2.*DeltaS2/(sqrt(bMirror-bField_I(iLast)))

  end subroutine get_bounced_drift

  !===============================================================

  subroutine get_bounced_VGradB(nPoint, L, bField_I, GradB_I,bMirror,iMirror_I,&
       dLength_I,Drift_I,RadialDistance_I,BouncedVGradB)

    integer, intent(in)  :: nPoint
    real,    intent(in)  :: L
    real,    intent(in)  :: bField_I(nPoint) 
    real,    intent(in)  :: bMirror  
    integer, intent(in)  :: iMirror_I(2)
    real,    intent(in)  :: dLength_I(nPoint-1)
    real,    intent(in)  :: Drift_I(nPoint), GradB_I(nPoint)
    real,    intent(in)  :: RadialDistance_I(nPoint)
    real,    intent(out) :: BouncedVGradB
    real                 :: DeltaS1, DeltaS2, b1, b2, Coeff
    real                 :: Temp, TempFirst,TempLast
    integer              :: iPoint, iFirst, iLast

    !-----------------------------------------------------------------------------

    iFirst = iMirror_I(1)
    iLast  = iMirror_I(2)

    BouncedVGradB    = 0.0
    if (iFirst > iLast) RETURN

    Coeff = sqrt(bMirror) 
    DeltaS1 = abs((bMirror-bField_I(iFirst))*&
         (dLength_I(iFirst-1))/(bField_I(iFirst-1)-bField_I(iFirst)))

    TempFirst = (1./bField_I(iFirst)) * Drift_I(iFirst) * GradB_I(iFirst)
    BouncedVGradB    = BouncedVGradB + TempFirst*Coeff*2.*DeltaS1/(sqrt(bMirror-bField_I(iFirst)))


    do iPoint = iFirst, iLast-1
       b1 = bField_I(iPoint)
       b2 = bField_I(iPoint+1)
       Temp = (1./bField_I(iPoint)) * Drift_I(iPoint) * GradB_I(iPoint)

       BouncedVGradB  =  BouncedVGradB  + Temp *Coeff*2.*dLength_I(iPoint)/(b1 - b2) &
            *( sqrt(bMirror  - b2) - sqrt(bMirror  - b1) )

    end do


    DeltaS2 = abs((bMirror-bField_I(iLast))*(dLength_I(iLast))/(bField_I(iLast+1)-bField_I(iLast)))

    TempLast = (1./bField_I(iLast)) * Drift_I(iLast) * GradB_I(iLast)
    BouncedVGradB   = BouncedVGradB + TempLast* Coeff*2.*DeltaS2/(sqrt(bMirror-bField_I(iLast)))


  end subroutine get_bounced_VGradB

  !===============================================================
  subroutine get_bounced_drift_new(nPoint, L, bField_I, bMirror,iMirror_I,& 
       dLength_I,Drift_I,BouncedDrift,RadialDistance_I)

    implicit none

    integer, intent(in)  :: nPoint
    real,    intent(in)  :: L
    real,    intent(in)  :: bField_I(nPoint)
    real,    intent(in)  :: bMirror
    integer, intent(in)  :: iMirror_I(2)
    real,    intent(in)  :: dLength_I(nPoint-1)
    real,    intent(in)  :: Drift_I(nPoint)
    real,    intent(in)  :: RadialDistance_I(nPoint)
    real,    intent(out) :: BouncedDrift
    real                 :: DeltaS1, DeltaS2, b1, b2, Coeff
    real                 :: v1,v2,c1,c2, alpha1,alpha2,vMirror
    integer              :: iPoint, iFirst, iLast

    !-----------------------------------------------------------------------------

    iFirst = iMirror_I(1)
    iLast  = iMirror_I(2)

    vMirror = 0.5*(Drift_I(iFirst)+Drift_I(iFirst-1))

    BouncedDrift    = 0.0  

    if (iFirst > iLast) RETURN

    Coeff = sqrt(bMirror)
    c1 = 3.*(sqrt(2.)-1.)
    c2 = sqrt(2.)-2.



    DeltaS1 = abs((bMirror-bField_I(iFirst))*&
         (dLength_I(iFirst-1))/(bField_I(iFirst-1)-bField_I(iFirst))) 

    BouncedDrift = BouncedDrift + Coeff* 2./3. * DeltaS1/&
         (bField_I(iFirst-1)-bField_I(iFirst))* &
         sqrt(bMirror-bField_I(iFirst)) * (-3.* Drift_I(iFirst) ) 

    do iPoint = iFirst, iLast -1

       b1 = bField_I(iPoint)
       b2 = bField_I(iPoint+1)

       v1 = Drift_I(iPoint)
       v2 = Drift_I(iPoint+1)

       alpha2 = sqrt(bMirror - b2) * ( c1* v2 - c2 * (vMirror - v2))
       alpha1 = sqrt(bMirror - b1) * ( c1* v1 - c2 * (vMirror - v1))

       BouncedDrift = BouncedDrift + Coeff* 2./3. * dLength_I(iPoint)/(b1-b2)&
            *(alpha2-alpha1)

    end do

    DeltaS2 = abs((bMirror-bField_I(iLast))*(dLength_I(iLast))/&
         (bField_I(iLast+1)-bField_I(iLast)))

    BouncedDrift = BouncedDrift + Coeff* 2./3. * DeltaS2/&
         (bField_I(iLast+1)-bField_I(iLast))*&
         sqrt(bMirror-bField_I(iLast)) * (-3.* Drift_I(iLast) ) 

  end subroutine get_bounced_drift_new



  !===============================================================

end module ModHeidiBACoefficients
