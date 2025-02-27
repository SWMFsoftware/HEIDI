!  Copyright (C) 2002 Regents of the University of Michigan,
! portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
subroutine heidi_init

  use ModHeidiSize,   ONLY: dT
  use ModHeidiMain,   ONLY: T, f107R, init_mod_heidi_main
  use ModHeidiDrifts, ONLY: j18,j6, P2, init_mod_heidi_drifts
  use ModHeidiWaves,  ONLY: init_mod_heidi_waves
  use ModProcHEIDI,      ONLY: iProc
  use ModInit,        ONLY: nSt, nKp, nIBC, i2,nPr, xn, lnc, i3
  use ModHeidiIO,     ONLY: write_prefix, time, iUnitStdout, tinj, iKp,&
       F107, iwpi, tint, nStep, year, day, ut, IsFramework 

  implicit none
  !--------------------------------------------------------------------------

  call init_mod_heidi_main
  call init_mod_heidi_waves
  call init_mod_heidi_drifts

  if (iProc == 0) then
     call IonoHeidiInit(year,day,ut)
  endif

  if (.not. IsFramework) T = TIME
  if (iProc == 0) then
     call write_prefix; write(iUnitStdOut,*) 'TIME =',TIME
  end if

  NST  = nint(TIME/DT/2.) + 1
  NKP  = nint(10800./DT/2.)
  NIBC = nint(TINJ/DT/2.)

  if (iProc==0) then
     call write_prefix; write(iUnitStdOut,*)'nSteps, nSteps in KP, nSteps IBC:',NST,NKP,NIBC
  end if

  call CONSTANT(NKP)
  I2=(NST-1)/NKP + 1
  I3 = NST
  if (IKP.ge.3) F107=F107R(I2)
  call ARRAYS
  call heidi_cepara
  call OTHERPARA
  call CURRENTSETUP
  call heidi_initial(LNC,XN,J6,J18)
 
  call THERMAL   ! Setup only
 
  call GEOSB ! sets up the BC conditions
  if (iwpi.gt.0) then
     call WAPARA
     call ANISCH
  end if
 
  !Start the calculation

  NPR=nint(TINT/DT/2.)
  if (NSTEP.lt.45) then
     if (iProc==0) then
        call write_prefix; write(iUnitStdOut,*) 'Times:',NST,NSTEP,NPR,NKP,NIBC,I2,DT,NSTEP*2.*DT
     end if
  end if

end subroutine heidi_init
