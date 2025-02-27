!  Copyright (C) 2002 Regents of the University of Michigan, portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
! INITIALIZATION Routines
!=========================================================================
subroutine IonoHeidiInit(year, day, ut)
  !\
  ! This routine sets the fine grid meshes for the
  ! northern and southern hemispheres.
  !/
  use ModIonoHeidi
  use ModNumConst, ONLY: cPi

  implicit none

  integer, intent(in) :: year, day
  real,    intent(in) :: ut
  integer             :: i,j
  real                :: dTheta_l, dPsi_l
  !-------------------------------------------------------------------------        
  dTheta_l = 0.50*cPi/real(IONO_nTheta-1)
  dPsi_l = 2.0*cPi/real(IONO_nPsi-1)

  do j = 1, IONO_nPsi
     IONO_NORTH_Theta(1,j) = 0.001
     IONO_NORTH_Psi(1,j) = real(j-1)*dPsi_l

     do i = 1, IONO_nTheta
        IONO_NORTH_Theta(i,j) = cPi*(0.5*real(i-1)/real(IONO_nTheta))
        IONO_NORTH_Psi(i,j) = IONO_NORTH_Psi(1,j)
     end do

     IONO_NORTH_Theta(IONO_nTheta,j) = 0.50*cPi
     IONO_NORTH_Psi(IONO_nTheta,j) = IONO_NORTH_Psi(1,j)
  end do

  do j = 1, IONO_nPsi
     IONO_SOUTH_Theta(1,j) = cPi-0.50*cPi
     IONO_SOUTH_Psi(1,j) = real(j-1)*dPsi_l
     do i = 1, IONO_nTheta
        IONO_SOUTH_Theta(i,j) = cPi*(0.5+0.5*real(i-1)/real(IONO_nTheta))
        IONO_SOUTH_Psi(i,j) = IONO_SOUTH_Psi(1,j)
     end do

     IONO_SOUTH_Theta(IONO_nTheta,j) = cPi-0.001
     IONO_SOUTH_Psi(IONO_nTheta,j) = IONO_SOUTH_Psi(1,j)
  end do

  IONO_NORTH_PHI = 0.00
  IONO_NORTH_JR = 0.00 
  IONO_NORTH_RCM_JR = 0.00 

  IONO_SOUTH_PHI = 0.00
  IONO_SOUTH_RCM_JR = 0.00

end subroutine IonoHeidiInit
!=========================================================================
subroutine IonoHeidiWriteOutput(ifile,time,IO_prefix,IO_suffix)
  !\
  ! INPUT/OUTPUT Routines ; ionosphere_write_output
  ! This routine writes out the fine grid 
  ! ionospheric solutions for the
  ! northern and southern hemispheres to
  ! a data file.
  !/
  use ModIonoHeidi
  use ModHeidiIO,  ONLY: NameOutputDir
  use ModNumConst, ONLY: cPi
  use ModIoUnit,   ONLY: io_unit_new

  implicit none

  integer,           intent(in) :: ifile
  real,              intent(in) :: time
  character (len=*), intent(in) :: IO_prefix
  character (len=*), intent(in) :: IO_suffix

  integer, parameter :: tec_type = 1
  integer, parameter :: idl_type = 2
  integer, parameter :: all_vars = 1
  integer, parameter :: min_vars = 2
  integer, parameter :: uam_vars = 3

  integer :: output_type, variables, year,Iunit, i, j
  character (len=11), parameter :: iono_dir="ionosphere/"
  character (len=2),  parameter :: iono_dir_path="./"
  character (len=4)             :: IO_ext=".dat"
  character (len=2)             :: sday, shour, sminute
  real                          :: day,hour,minute
  !-------------------------------------------------------------------------
  variables = min_vars
  output_type = idl_type

  if (plot_vars(ifile) == 'minimum') then
     variables = min_vars
  elseif (plot_vars(ifile) == 'maximum') then
     variables = all_vars
  elseif (plot_vars(ifile) == 'uam') then
     variables = uam_vars
  endif

  if (plot_form(ifile) == 'idl') then
     output_type = idl_type
  elseif (plot_form(ifile) == 'tec') then
     output_type = tec_type
  endif

  Iunit = io_unit_new()

  if (output_type == idl_type) then
     IO_ext = ".idl"
  elseif (output_type == tec_type) then
     IO_ext = ".tec"
  endif

  ! Time is in seconds from the beginning of the run, not decimal days
  day = int(time/86400.)
  hour = int((time - day)/3600.)
  minute = int((time - day - hour*3600.)/60.)

  if (day < 10) then
     write (sday,'(a1,i1)') '0',int(day)
  else
     write (sday,'(i2)') int(day)
  endif

  if (hour < 10) then
     write (shour,'(a1,i1)') '0',int(hour)
  else
     write (shour,'(i2)') int(hour)
  endif

  if (minute < 10) then
     write (sminute,'(a1,i1)') '0',int(minute)
  else
     write (sminute,'(i2)') int(minute)
  endif

  open(unit=Iunit,file=NameOutputDir//iono_dir//"it_"//&
       IO_suffix//IO_ext, &
       status="unknown")

  if (output_type == idl_type) then

     write(Iunit, '(a)')  'TITLE='
     write(Iunit, '(a)')  '  "BATSRUS: Ionospheric Potential Solution"'

     write(Iunit, *) ' '

     write(Iunit, '(a)')  'NUMERICAL VALUES'
     if (variables == min_vars) then
        write(Iunit, '(I5,a)')           7, ' nvars'
     endif
     write(Iunit, '(I5,a)') IONO_nTheta, ' nTheta'
     write(Iunit, '(I5,a)')   IONO_nPsi, ' nPhi'

     write(Iunit, *) ' '

     write(Iunit, '(a)') 'VARIABLE LIST'

     if (variables == min_vars) then

        write(Iunit, '(I5,a)')  1, ' Theta [deg]'
        write(Iunit, '(I5,a)')  2, ' Psi [deg]'
        write(Iunit, '(I5,a)')  3, ' Jr [mA/m^2]'
        write(Iunit, '(I5,a)')  4, ' Phi [kV]'
        write(Iunit, '(I5,a)')  5, ' Density [#/cc]'
        write(Iunit, '(I5,a)')  6, ' Pressure [Pa]'
        write(Iunit, '(I5,a)')  6, ' Temperature [eV]'

     endif

     write(Iunit, *) ' '

     write(Iunit, '(a)') 'TIME'
     write(Iunit, '(I5,a)')  0, ' Year'
     write(Iunit, '(I5,a)')  0, ' Month'
     write(Iunit, '(I5,a)')  int(day), ' Day'
     write(Iunit, '(I5,a)')  int(hour), ' Hour'
     write(Iunit, '(I5,a)')  int(minute), ' Minute'
     write(Iunit, '(I5,a)')  0, ' Second'
     write(Iunit, '(I5,a)')  0, ' Millisecond'

     write(Iunit, *) ' '
     write(Iunit, '(a)') 'BEGIN NORTHERN HEMISPHERE'

  elseif (output_type == tec_type) then

     write(Iunit, *)  'TITLE="BATSRUS: Ionospheric Potential Solution"'

     if (variables == min_vars) then

        write(Iunit, *)  'VARIABLES= "Theta [deg]","Psi [deg]"'
        write(Iunit, *)  ' "JR [`mA/m^2]","PHI [kV]",'
        write(Iunit, *)  ' "Density [#/cc]","Pressure [Pa]","Temperature [eV]"'

     endif

     write(Iunit, *)  'ZONE T="Northern Hemisphere" ','I= ',IONO_nTheta, &
          ' J= ',IONO_nPsi,' F=POINT'

  endif

  if (variables == min_vars) then
     do j = 1, IONO_nPsi
        do i = 1, IONO_nTheta
           write(Iunit,fmt="(6(E13.5))")  &
                (360.00/(2.00*cPi))*IONO_NORTH_Theta(i,j), &
                (360.00/(2.00*cPi))*IONO_NORTH_Psi(i,j), &
                1.0e06*IONO_NORTH_RCM_JR(i,j),   &
                1.0e-03*IONO_NORTH_PHI(i,j), &
                IonoGmDensity(i,j), &
                IonoGmPressure(i,j), &
                IonoGmTemperature(i,j)
        end do
     end do
  endif

  if (output_type == idl_type) then
     write(Iunit, *) ' '
     write(Iunit, '(a)') 'BEGIN SOUTHERN HEMISPHERE'
  elseif (output_type == tec_type) then

     write(Iunit, *)  'ZONE T="Southern Hemisphere" ','I= ',IONO_nTheta, &
          ' J= ',IONO_nPsi,' F=POINT'
  endif

  if (variables == min_vars) then
     do j = 1, IONO_nPsi
        do i = 1, IONO_nTheta
           write(Iunit,fmt="(6(E13.5))")  &
                (360.00/(2.00*cPi))*IONO_SOUTH_Theta(i,j), &
                (360.00/(2.00*cPi))*IONO_SOUTH_Psi(i,j), &
                1.0e06*IONO_SOUTH_RCM_JR(i,j),   &
                1.0e-03*IONO_SOUTH_PHI(i,j), &
                IonoGmDensity(Iono_nTheta+i-1,j), &
                IonoGmPressure(Iono_nTheta+i-1,j), &
                IonoGmTemperature(Iono_nTheta+i-1,j)
        end do
     end do
  endif

  close(UNIT=Iunit)

end subroutine IonoHeidiWriteOutput
!=========================================================================

