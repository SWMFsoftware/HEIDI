SHELL=/bin/sh

default: HEIDI

include Makefile.def

install: 

HEIDI:
	@cd ${SHAREDIR};  	make LIB
	@cd ${NOMPIDIR};	make LIB
	@cd ${TIMINGDIR}; 	make LIB 
	@cd ${EMPIRICALIEDIR};	make LIB
	@cd ${EMPIRICALGMDIR};	make LIB
	@cd src;	        make HEIDI

LIB:
	@cd ${SHAREDIR};  	make LIB
	@cd ${NOMPIDIR};	make LIB
	@cd ${TIMINGDIR}; 	make LIB 
	@cd ${EMPIRICALIEDIR};	make LIB
	@cd ${EMPIRICALGMDIR};	make LIB
	@cd src;	        make LIB
	@cd srcInterface;	make LIB

OUTDIR    = plots
TESTDIR1  = run_test_analytic
TESTDIR2  = run_test_numeric
HEIDIDIR  = ${DIR}/IM/HEIDI
CHECKDIR  = output
SADIR     = run_heidi


.NOTPARALLEL: test

test:
	@rm -f *.diff
	-@(make test_analytic)	

test_analytic:
	@echo "test_compile..." > test_analytic.diff
	make   test_compile
	@echo "test_rundir..." >> test_analytic.diff
	make   test_analytic_rundir
	@echo "test_run..."    >> test_analytic.diff
	make   test_analytic_run
	@echo "test_check..."  >> test_analytic.diff
	make   test_analytic_check

test_numeric:
	@echo "test_compile..." > test_numeric.diff
	make   test_compile
	@echo "test_rundir..." >> test_numeric.diff
	make   test_numeric_rundir
	@echo "test_run..."    >> test_numeric.diff
	make   test_numeric_run
	@echo "test_check..."  >> test_numeric.diff
	make   test_numeric_check


test_compile:
	make HEIDI


test_analytic_rundir:
	rm -rf ${TESTDIR1}
	make rundir RUNDIR=${TESTDIR1} STANDALONE="YES" PWDIR=`pwd`
	cd input; cp PARAM.analytic.in ../${TESTDIR1}/PARAM.in

test_numeric_rundir:
	rm -rf ${TESTDIR2}
	make rundir RUNDIR=${TESTDIR2} STANDALONE="YES" PWDIR=`pwd`
	cd input; cp PARAM.numeric.in ../${TESTDIR2}/PARAM.in

# The tests run on 1 or 2 PE-s only
test_analytic_run: 
	cd ${TESTDIR1}; ${PARALLEL} ${NPFLAG} 2 ./HEIDI.exe > runlog

test_numeric_run: 
	cd ${TESTDIR2}; ${PARALLEL} ${NPFLAG} 2 ./HEIDI.exe > runlog

test_analytic_check:
	${SCRIPTDIR}/DiffNum.pl -t -r=0.001 -a=1e-10 \
		${TESTDIR1}/IM/${OUTDIR}/hydrogen/test1_h_prs.002 \
		${CHECKDIR}/test1_h_prs_analytic.002 \
			> test_analytic.diff
	ls -l test_analytic.diff

test_numeric_check:
	${SCRIPTDIR}/DiffNum.pl -t -r=0.001 -a=1e-10 \
		${TESTDIR2}/IM/${OUTDIR}/hydrogen/test1_h_prs.002 \
		${CHECKDIR}/test1_h_prs_numeric.002 \
			> test_numeric.diff
	ls -l test_numeric.diff



rundir_heidi:
	make rundir RUNDIR=${SADIR} STANDALONE="YES" PWDIR=`pwd`
	cd input; cp PARAM.analytic.in ../${SADIR}/PARAM.in


rundir:
	mkdir -p ${RUNDIR}/IM
	@(cd ${RUNDIR}; \
		if [ ! -e "EIE/README" ]; then \
			ln -s ${EMPIRICALIEDIR}/data EIE;\
		fi;)
	cd ${RUNDIR}/IM; \
		mkdir input plots restartIN restartOUT
	cd ${RUNDIR}/IM/plots; \
		mkdir electron hydrogen helium oxygen ionosphere
	@(if [ "$(STANDALONE)" != "NO" ]; then \
		cd ${RUNDIR} ; \
		ln -s ${BINDIR}/HEIDI.exe .;\
	fi);
	cd ${RUNDIR}/IM/input; \
		ln -s ${HEIDIDIR}/input/* .; cp ${HEIDIDIR}/data/input/*.dat .
	cd ${RUNDIR}/IM/restartIN; \
		cp ${HEIDIDIR}/data/input/*.gz .; gunzip *.gz

clean:
	@(if [ -r "Makefile.conf" ]; then  \
		cd src;             make clean;\
		cd ../srcInterface; make clean;\
	fi)

distclean: 
	./Config.pl -uninstall

allclean:
	@(if [ -r "Makefile.conf" ]; then \
		cd src;             make distclean;\
		cd ../srcInterface; make distclean;\
	fi)
	rm -f *~

