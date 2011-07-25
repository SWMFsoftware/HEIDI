Module ModHeidiMain
  !\
  ! The main variable definition module for the HEIDI program.
  ! Mike Liemohn, March 2006
  !/
  ! Include the parameter settings for MPI parallel processing
  use ModMpi
  use ModHeidiSize
  use ModNumConst

  ! Basic physical constants: Earth radius and dipole coefficient
  real :: Re, DipoleFactor
  
  ! Define "constants" of the simulation
  real :: q,me,mp,dkp,fluxfact(NS),pi
  real ::dayr(48),rkph(48),f107r(48),apr(48),rsunr(48)
  
  ! Define independent variables and grid-related factors
  integer :: upa(NR)
  real    :: DL1,DR,LZ(NR),Z(NR),BE(NR,Slen),PHI(NT),DPHI,MLT(NT)
  real    :: MAS(NS),M1(NS),WE(NE),DE(NE),EKEV(NE)
  real    :: V(NE,NS) = 0.0
  real    :: VBND(NE,NS),MU(NPA),DMU(NPA),WMU(NPA),EBND(NE)
  real    :: CONMU1,CONMU2,FFACTOR(NR,NT,NE,NPA),FACMU(NPA,NR,NT),CONF1,CONF2
  real    :: CEDR(NR,NT,NE,NPA,NS),CIDR(NR,NT,NE,NPA,NS)
  
  ! Define flux variable, and a few others
  real ::F2(NR,NT,NE,NPA,NS)=0.0
  real ::A,T,FGEOS(NT,NE,NPA,NS)
  
  ! Define parameters based on grid variables
  real :: ENER(NR,NS),FACTOR(NS)=0.0
  real :: LEC(NR,NS),ECOF(NR),WCD(NR,NT)
  
  ! Define thermal plasma variables
  real    :: xne(NR,NT)
  integer :: itherminit,ithermfirst
  
  
  ! Define parallel computing variables
  integer :: nParallelSpecies(NS)
  integer :: nSpecies, iSpecies

  real :: funt(nPa,nR,nT),funi(nPa,nR,nT)
  real, dimension(nPoint,nR,nT)   :: BHeidi_III, SHeidi_III, RHeidi_III
  real, dimension(nPoint,nR,nT)   :: bGradB1xHeidi_III,bGradB1yHeidi_III, bGradB1zHeidi_III 
  real, dimension(nPoint,nR,nT)   :: BxHeidi_III, ByHeidi_III, BzHeidi_III
  real, dimension(3,nPoint,nR,nT) :: Xyz_VIII
  real, dimension(nR,nT,nE,nPA)   :: dEdt_IIII,VPhi_IIII,VR_IIII
  real, dimension(nR,nT,nE,nPA)   :: dMudt_III 
  real :: NeutralHydrogen(nR,nT,nPa) = 0.0
  real :: bFieldMagnitude_III(nPoint,nR,nT)
  
  logical :: IsBFieldNew
  real, parameter::RadToDeg = 180.0/cPi


end Module ModHeidiMain

