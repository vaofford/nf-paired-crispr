#! /bin/bash

set -xe

if [[ -z "${TMPDIR}" ]]; then
  TMPDIR=/tmp
fi

set -u

if [ "$#" -lt "1" ] ; then
  echo "Please provide an installation path such as /opt/ICGC"
  exit 1
fi

# get path to this script
SCRIPT_PATH=`dirname $0`;
SCRIPT_PATH=`(cd $SCRIPT_PATH && pwd)`

# get the location to install to
INST_PATH=$1
mkdir -p $1
INST_PATH=`(cd $1 && pwd)`
echo $INST_PATH

# get current directory
INIT_DIR=`pwd`

CPU=`grep -c ^processor /proc/cpuinfo`
if [ $? -eq 0 ]; then
  if [ "$CPU" -gt "6" ]; then
    CPU=6
  fi
else
  CPU=1
fi
echo "Max compilation CPUs set to $CPU"

SETUP_DIR=$INIT_DIR/install_tmp
mkdir -p $SETUP_DIR/distro # don't delete the actual distro directory until the very end
mkdir -p $INST_PATH/bin
cd $SETUP_DIR

# make sure tools installed can see the install loc of libraries
set +u
export LD_LIBRARY_PATH=`echo $INST_PATH/lib:$LD_LIBRARY_PATH | perl -pe 's/:\$//;'`
export LIBRARY_PATH=`echo $INST_PATH/lib:$LIBRARY_PATH | perl -pe 's/:\$//;'`
export C_INCLUDE_PATH=`echo $INST_PATH/include:$C_INCLUDE_PATH | perl -pe 's/:\$//;'`
export PATH=`echo $INST_PATH/bin:$PATH | perl -pe 's/:\$//;'`
export MANPATH=`echo $INST_PATH/man:$INST_PATH/share/man:$MANPATH | perl -pe 's/:\$//;'`
export PERL5LIB=`echo $INST_PATH/lib/perl5:$PERL5LIB | perl -pe 's/:\$//;'`
set -u

# FastQC
if [ ! -e $SETUP_DIR/FastQC.success ]; then
#  curl -sSL --retry 10 -o fastqc.zip http://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v${VER_FASTQC}.zip
#  unzip -qu fastqc.zip -d $INST_PATH
#  cd $INST_PATH/FastQC
#  chmod +x fastqc
#  cd $SETUP_DIR
#  rm -rf fastqc.zip
  touch $SETUP_DIR/FastQC.success
fi

# MultiQC
if [ ! -e $SETUP_DIR/MultiQC.success ]; then
#  pip3 install multiqc==${VER_MULTIQC}
  touch $SETUP_DIR/MultiQC.success
fi

# htslib
if [ ! -e $SETUP_DIR/htslib.success ]; then
	curl -sSL --retry 10 -o htslib.tar.gz https://github.com/samtools/htslib/archive/${VER_HTSLIB}.tar.gz
	mkdir htslib
	tar --strip-components 1 -C htslib -xzf htslib.tar.gz
	cd htslib
	autoheader
	autoconf
	./configure --prefix=$INST_PATH
	make
	make install
	cd $SETUP_DIR
	rm -rf htslib.* htslib/*
	find $INST_PATH -name "sam.h"
	touch $SETUP_DIR/htslib.success
fi

# fqtools
if [ ! -e $SETUP_DIR/fqtools.success ]; then
	mkdir $INST_PATH/fqtools
	curl -sSL --retry 10 -o distro.tar.gz https://github.com/alastair-droop/fqtools/archive/v${VER_FQTOOLS}.tar.gz
	tar --strip-components 1 -C $INST_PATH/fqtools  -xzf distro.tar.gz
  	cd $INST_PATH/fqtools
	sed -i "3s:HTSDIR=\.\/htslib:HTSDIR=$INST_PATH\/htslib\/lib:" Makefile
	sed -i "22s:htslib\/sam\.h:$INST_PATH\/include\/htslib\/sam\.h:" src/fqheader.h
	cat src/fqheader.h
	make
	cd $SETUP_DIR
	rm -rf distro.* distro/*
	touch $SETUP_DIR/fqtools.success
fi

# Nextflow
#if [ ! -e $SETUP_DIR/Nextflow.success ]; then
#  curl -s https://get.nextflow.io | bash
#  mv nextflow $INST_PATH/bin/nextflow
#fi
