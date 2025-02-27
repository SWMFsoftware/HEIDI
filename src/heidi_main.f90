!  Copyright (C) 2002 Regents of the University of Michigan, portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
!************************************************************************
! PROGRAM HEIDI - 
!   ***  Hot Electron and Ion Drift Integrator  ***
! A program to calculate the growth and decay of a given population of 
! ring current ions and electrons solving the bounce-averaged 
! Boltzmann equation considering drifts, charge exchange, atmospheric 
! loss, wave-particle interactions, electric and magnetic field effects
! and feedback, and Coulomb collisions.
!
! Numerical scheme for cons terms: Lax-Wendroff + superbee flux limiter
! Converted from mram05.f into heidi010.f90, March 2006, Mike Liemohn
!***********************************************************************

!       NR=no. grids in radial direction, NT=no. grids in azimuth,
!	NE=no. of energy grids, NS=no. of species (e-, H+, He+, O+),
!	NPA=no. of grids in equatorial pitch angle
!***********************************************************************
program heidi_main

  use ModHeidiIO 
  use ModInit
  use ModProcHEIDI
  use ModHeidiMain
  use ModHeidiDrifts, ONLY:j6, j18
  use CON_planet, ONLY: init_planet_const, set_planet_defaults, get_planet
  
  implicit none 
  logical :: IsUninitialized = .true.
  !---------------------------------------------------------------------------
  
  call MPI_INIT(iError)
  iComm= MPI_COMM_WORLD

  call MPI_COMM_RANK(iComm, iProc, iError)
  call MPI_COMM_SIZE(iComm, nProc, iError)   
  
  IsFramework = .false.
  IsBFieldNew = .true.
  
  ! Initialize the planet, default planet is Earth
  call init_planet_const 
  call set_planet_defaults

  call get_planet(RadiusPlanetOut = Re, DipoleStrengthOut = DipoleFactor)
  DipoleFactor = DipoleFactor*Re**3


  ! Read and check input file
  call heidi_read
  call heidi_check

  if(IsUninitialized)then
     call heidi_init
     IsUninitialized = .false.
  end if

  do i3 = nst, nstep
     write(*,*) '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
     write(*,*) 'MAIN TIME: T, time=', T, time
     write(*,*) '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'

     call heidi_run
     !IsBFieldNew = .false.
     IsBFieldNew = .true.
  end do			! end time loop

  close(iUnitSal)           ! Closes continuous output file
  close(iUnitSw1)           ! Closes sw1 input file
  close(iUnitSw2)           ! Closes sw2 input file
  close(iUnitMpa)           ! Closes MPA input file
  close(iUnitSopa)          ! Closes SOPA input file
  close(iUnitPot)           ! Closes FPOT input file

  call MPI_BARRIER(iComm,iError) 
  call MPI_finalize(iError)

end program heidi_main
