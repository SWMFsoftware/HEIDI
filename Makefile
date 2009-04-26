default: HEIDI

include Makefile.def

INSTALLFILES =  src/Makefile.DEPEND \
		src/Makefile.RULES \
		srcInterface/Makefile.DEPEND

install: 
	touch ${INSTALLFILES}

#
#       General Housekeeping
#

HEIDI:  install
	@cd ${SHAREDIR};  	make LIB
	@cd ${NOMPIDIR};	make LIB
	@cd ${TIMINGDIR}; 	make LIB 
	@cd ${EMPIRICALIEDIR};	make LIB
	@cd ${EMPIRICALGMDIR};	make LIB
	@cd src;	        make HEIDI

LIB:  install
	@cd ${SHAREDIR};  	make LIB
	@cd ${NOMPIDIR};	make LIB
	@cd ${TIMINGDIR}; 	make LIB 
	@cd ${EMPIRICALIEDIR};	make LIB
	@cd ${EMPIRICALGMDIR};	make LIB
	@cd src;	        make LIB
	@cd srcInterface;	make LIB

TESTDIR = run_test
UADIR = ${DIR}/UA/GITM/srcData

test:
	@echo "test_compile..." > test.diff
	make   test_compile
	@echo "test_rundir..." >> test.diff
	make   test_rundir
	@echo "test_run..."    >> test.diff
	make   test_run
	@echo "test_check..."  >> test.diff
	make   test_check

test_compile:
	make HEIDI

test_rundir:
	rm -rf ${TESTDIR}
	make rundir RUNDIR=${TESTDIR} STANDALONE="YES" PWDIR=`pwd`
	cd input; cp *.in *.dat *.glo *.initial *.unff ../${TESTDIR}
	mkdir ${TESTDIR}/ionosphere

test_run: 
	cd ${TESTDIR}; ${MPIRUN} ./HEIDI.exe

test_check:
	${SCRIPTDIR}/DiffNum.pl -t -r=0.001 -a=1e-8 \
		${TESTDIR}/IM/plots/test1_h_prs.002 \
		output/test1_h_prs.002 \
			> test.diff
	ls -l test.diff

clean: install
	@(if [ -r "Makefile.conf" ]; then  \
	cd src;                      make clean;\
	cd ../srcInterface;             make clean;\
	fi)

distclean: 
	./Config.pl -uninstall

allclean: install
	@(if [ -r "Makefile.conf" ]; then \
		cd src;                      make distclean;\
		cd ../srcInterface;          make distclean;\
	fi)
	rm -f *~
#
#       Create run directories
#

rundir:
	mkdir -p ${RUNDIR}/IM
	cd ${RUNDIR}/IM; \
		mkdir input plots restartIN restartOUT 
	cp ${EMPIRICALIEDIR}/ED_hpke.noaa ${RUNDIR}/IM/hpke.noaa
	cp ${EMPIRICALIEDIR}/*.cofcnts ${RUNDIR}/IM/
	cd ${RUNDIR}/IM; \
		mkdir plots/ionosphere
	@(if [ "$(STANDALONE)" != "NO" ]; then \
		cd ${RUNDIR} ; \
		ln -s ${BINDIR}/HEIDI.exe .;\
	fi);

