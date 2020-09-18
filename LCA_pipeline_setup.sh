#!/bin/bash
# A: Lisa Sikkema, 2020
# D: download files, set up conda environment and build reference genome for Lung Cell Atlas cellranger pipeline

# version of pipeline
pipeline_version="0.1.0"

# parameter defaults: 

# Ensembl release
ensrel="99"
# Genome string
genomestring="GRCh38"
# species
species="homo_sapiens"
# Expected cell ranger version
expectedcrv="3.1.0"
# Resources for mkref
# number of cores
nthreads="20"
# Memory in GB
memgb="48"
# Include Sars-cov2 genome:
incl_sarscov2=false
# script parts to run/skip:
download_files=true
create_env=true
build_ref_genome=true
download_ensembl_files=true



usage() {
	cat <<HELP_USAGE
	
	Lung Cell Atlas pipeline version: v${pipeline_version}

	Usage: $(basename "$0") [-hwcutmsegDCRLS] 

		-h 			show this help text

		Mandatory arguments:

		-w <path_to_work_dir> 	path to working directory. Testdata, reference
					genomes, log files etc. will be stored here. 
		-c <path_to_envs_dir>	path to envs directory from your miniconda or 
					anaconda, with trailing slash, e.g. 
					/Users/doejohn/miniconda3/envs/
		-u <user:pass>		user:pass received from Lung Cell Atlas to 
					acquire access to files for download


		Optional arguments (with default settings):

		-t <n_threads>		number of threads to be used by cellranger mkref 
					(default: ${nthreads})
		-m <mem_in_Gb>		memory in GB to be used by cellranger mkref 
					(default: ${memgb})
		-s <species>		species for genome building. Use homo_sapiens 
					for human. (default: ${species})
		-e <ensembl_release>	ensembl release of reference genome to build. 
					(default: ${ensrel})
		-g <genome_release> 	genome release, must match with the 
					corresponding Ensembl release (see also Ensembls 
					fa file name for the release), use without the 
					patch id (e.g. GRCh37; GRCh38, GRCm38) 
					(default: ${genomestring})

		Optional arguments to skip parts of script:

		-D <true|false>		include download of required files. Set this 
					to false if files were already downloaded and 
					you want to skip this step. (default: ${create_env})
		-C <true|false>		include creation of conda environment. Set this to 
					false if conda environment is already created 
					and you want to skip this step. 
					(default: ${download_files})
		-R <true|false>		include building of reference genome. Set this 
					to false if reference genome has already been 
					built and you want to skipt this step. 
					(default: ${build_ref_genome})
		-L <true|false>		include download of ensembl files needed to build
					reference genome. Set to false if the files were already
					downloaded in a previous run. Set to true otherwise.
					If set to true, any existing folders in your 
					[work_dir]/refgenomes/ directory matching with the 
					specified species, ensembl_release and genome_release 
					will be removed. If set to false, the necessary 
					downloaded files should be present in your refgenomes 
					folder. (default: ${download_ensembl_files})

		Optional argument to include Sars-CoV2 in the reference genome:

		-S <true|false>		include Sars-cov2 in the reference genome. Set 
					this to true if Sars-cov2 should be included. 
					(default: ${incl_sarscov2})
	
		
HELP_USAGE
}

# TAKE IN ARGUMENTS

# go through optional arguments:
# preceding colon after getopts: don't allow for any automated error messages
# colon following flag letter: this flag takes in an argument
while getopts ":hw:c:u:t:m:s:e:g:D:C:R:L:S:" opt; do
	# case is bash version of 'if' that allows for multiple scenarios
	case "$opt" in
		# if h is added, print usage and exit
		h ) usage
			exit
			;;

		t ) nthreads=$OPTARG
			;; # continue
		m ) memgb=$OPTARG
			;;
		s ) species=$OPTARG
			;;
		e ) ensrel=$OPTARG
			;;
		g ) genomestring=$OPTARG
			;;
		w ) work_dir=$OPTARG
			;;
		c ) conda_envs_dir=$OPTARG
			;;
		u ) user_pass=$OPTARG
			;;
		D ) download_files=$OPTARG
			;;
		C ) create_env=$OPTARG
			;;
		R ) build_ref_genome=$OPTARG
			;;
		L ) download_ensembl_files=$OPTARG
			;;
		S ) incl_sarscov2=$OPTARG
			;;
		# if unknown flag, print error message and put it into stderr
		\? ) echo "Invalid option: $OPTARG" >&2
			usage
			exit 1
			;;
		# if argument is missing from flag that requires argument, 
		# print error and exit 1.
		# the print and echo outputs are sent to stderr file?
		# then exit 1
		: ) printf "missing argument for -%s\n" "$OPTARG" >&2
			echo "$usage" >&2
			exit 1
			;;
	esac
done
# move to next argument, and go through loop again:
shift $((OPTIND -1))

# CHECK PASSED ARGUMENTS/PARAMETERS:

# check if arguments specifying steps to skip/include (-DCR) are set to either true or false
# first convert them to lower case:
download_files="${download_files,,}"
download_ensembl_files="${download_ensembl_files,,}"
create_env="${create_env,,}"
build_ref_genome="${build_ref_genome,,}"
incl_sarscov2="${incl_sarscov2,,}"

# check if they're set to either true or false
if [ "$download_files" != "true" ] && [ "$download_files" != "false" ]; then
	echo "-D flag can only be set to 'true' or 'false'! exiting."
	exit 1
fi
# do the same for create_env:
if [ "$create_env" != "true" ] && [ "$create_env" != "false" ]; then
	"-C flag can only be set to 'true' or 'false'! exiting."
	exit 1
fi
# and for ref genome:
if [ "$build_ref_genome" != "true" ] && [ "$build_ref_genome" != "false" ]; then
	echo "-R flag can only be set to 'true' or 'false'! exiting."
	exit 1
fi


# if files have to be downloaded, then check if user_pass argument was provided:
# -z is True if string has length 0
if [ "$download_files" == "true" ] && [ -z $user_pass ]; then
	echo "user pass argument (-u flag) not provided. Exiting." 
	exit 1
fi


# check if conda_envs_dir argument was passed:
if [[ ("$create_env" == "true" || "$build_ref_genome" == "true") && -z $conda_envs_dir ]]; then 
	echo "conda environment directory (-c flag) argument not provided. Exiting." 
	exit 1
fi 

# check if conda_envs_dir is a directory:
if [ "$create_env" == "true" ] || [ "$build_ref_genome" == "true" ]; then
	# check if it is a directory (if not: exit), and if directory ends with /envs. (If not, only print a warning.)
	if ! [ -d $conda_envs_dir ]; then
		echo "Specified conda_envs_dir $conda_envs_dir does not exist. Exiting." 
		exit 1
	elif [[ $conda_envs_dir != */envs/ ]]; then
		echo "Warning: Specified conda envs directory $conda_envs_dir does not end with \"/envs/\". Make sure a trailing slash is included. Is this the correct directory?"
	fi
fi

# check if workdir argument was passed:
if [ -z $work_dir ]; then
	echo "no argument provided for -w flag (work_dir). Exiting."
	exit 1
fi

# check if workdir is a directory
if ! [ -d $work_dir ]; then
	echo "the provided work_dir (-w flag) is not a directory. Exiting."
	exit 1
fi

# if reference genome build is included, check if $incl_sarscov2 is either true or false:
if [ "$build_ref_genome" == "true" ]; then
	if [ "$incl_sarscov2" != "true" ] && [ "$incl_sarscov2" != "false" ]; then
	echo "-S flag can only be set to 'true' or 'false'! exiting."
	exit 1
	fi
fi

# if reference genome build is included, check if $download_ensembl_files is set to either true or false
if [ "$build_ref_genome" == "true" ]; then
	if [ "$download_ensembl_files" != "true" ] && [ "$download_ensembl_files" != "false" ]; then
	echo "-L flag can only be set to 'true' or 'false'! exiting."
	exit 1
	fi
fi


# CREATE LOG AND PRINT PARAMETERS

# store current path as script_dir
script_dir=`pwd`

# cd into workpath and store full path (wihtout trailing slash)
cd $work_dir
work_dir=`pwd`
# Log filenname
LOGFILE=$work_dir/"LOG_LCA_pipeline_setup.log"
# Check if logfile exists
if [ -f ${LOGFILE} ]; then
	echo "ERROR: LOG file ${LOGFILE} already exists. please remove. exit."
	exit 1
fi

# Create log file and add DATE
echo `date` > ${LOGFILE}
echo "Log file saved in : ${LOGFILE}"
# print pipeline version
echo "Lung Cell Atlas pipeline version: v${pipeline_version}" | tee -a ${LOGFILE}

# Print which steps will be skipped or included:
echo "STEPS TO BE INCLUDED/SKIPPED:" | tee -a ${LOGFILE}

# print for each step if it is included or skipped
if [ "$download_files" == "true" ]; then
	echo "downloading of required files will be included" | tee -a ${LOGFILE}
elif [ "$download_files" == "false" ]; then
	echo "downloading of required files will be skipped" | tee -a ${LOGFILE}
fi
# do the same for create_env:
if [ "$create_env" == "true" ]; then
	echo "creation of conda environment will be included" | tee -a ${LOGFILE}
elif [ "$create_env" == "false" ]; then
	echo "creation of conda environment will be skipped" | tee -a ${LOGFILE}
fi
# and for build_ref_genome
if [ "$build_ref_genome" == "true" ]; then
	echo "building of reference genome will be included" | tee -a ${LOGFILE}
	if [ "$download_files" == "false" ]; then
		echo "download of files from ensembl needed for refgenome building will be skipped." | tee -a ${LOGFILE}
	fi
	if [ "$incl_sarscov2" == "true" ]; then
	echo "Sars-cov2 genome will be added to the reference genome." | tee -a ${LOGFILE}
	fi
elif [ "$build_ref_genome" == "false" ]; then
	echo "building of reference genome will be skipped" | tee -a ${LOGFILE}
fi

# print parameters. tee command (t-split) splits output into normal printing and a second target, 
# in this case the log file to which it will -a(ppend) the output.
# i.e. parameters are printed and stored in logfile.
echo "Params:" | tee -a ${LOGFILE}
echo "cellranger version expected: ${expectedcrv}, Ensembl release: ${ensrel}, Genome release: ${genomestring}, Species: ${species}" | tee -a ${LOGFILE}
echo "nthreads: ${nthreads}, memgb: ${memgb}" | tee -a ${LOGFILE}
echo "user:pass provided" | tee -a ${LOGFILE}
echo "work directory: $work_dir" | tee -a ${LOGFILE}
echo "conda_envs_dir: $conda_envs_dir" | tee -a ${LOGFILE}

# let user confirm parameters:
read -r -p "Are the parameters correct? Continue? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
	echo "Parameters confirmed." | tee -a ${LOGFILE}
else
	echo "Parameters not confirmed, exit." | tee -a ${LOGFILE}
	exit 1
fi




# DOWNLOAD THE REQUIRED FILES, if $download_files == true:
if [ "$download_files" == "true" ]; then
	# now download the tar file:
	echo "We will download the necessary files now, this shouldn't take too long..." | tee -a ${LOGFILE}

	curl --user $user_pass https://hmgubox2.helmholtz-muenchen.de/public.php/webdav/LCA_pipeline_downloads.tar.gz --output $work_dir/LCA_pipeline_downloads.tar.gz -k
	curl --user $user_pass https://hmgubox2.helmholtz-muenchen.de/public.php/webdav/LCA_pipeline_downloads_CHECKSUM --output $work_dir/LCA_pipeline_downloads_CHECKSUM -k

	echo "Done." | tee -a ${LOGFILE}
	# validate that file is intact and not corrupted using checksum:
	echo "Checking md5sum of downloaded file..." | tee -a ${LOGFILE}
	md5sum -c $work_dir/LCA_pipeline_downloads_CHECKSUM | tee -a ${LOGFILE}
	# now unpack downloaded file:
	echo "Unpacking downloaded tar file now..." | tee -a ${LOGFILE}
	tar -xzvf $work_dir/LCA_pipeline_downloads.tar.gz | tee -a ${LOGFILE}
	echo "Done" | tee -a ${LOGFILE}
	# move directories up one folder and remove donwload dir + tar
	mv $work_dir/LCA_pipeline_downloads/* $work_dir/ 2>&1 | tee -a ${LOGFILE}
	rmdir $work_dir/LCA_pipeline_downloads 2>&1 | tee -a ${LOGFILE}
	rm $work_dir/LCA_pipeline_downloads.tar.gz 2>&1 | tee -a ${LOGFILE}
fi

# CREATE CONDA ENVIRONMENT, if $create_env == true:

path_to_env="${conda_envs_dir}cr3-velocyto-scanpy"

if [ "$create_env" == "true" ]; then
	echo "Creating conda environment in ${path_to_env}... NOTE! This can take a few hours..." | tee -a ${LOGFILE}
	echo "start time: `date`" | tee -a ${LOGFILE}
	# script seems to terminate after conda create command, so now running from subshell (parentheses)
	(
		conda create --prefix $path_to_env -c $work_dir/conda-bld -c conda-forge -c bioconda -y cellranger=3.1.0=0 scanpy=1.4.4.post1=py_3 velocyto.py=0.17.17=py36hc1659b7_0 samtools=1.10=h9402c20_2 conda=4.8.2=py36_0 nextflow=19.10 java-jdk=8.0.112 | tee -a ${LOGFILE}
		) | tee -a ${LOGFILE}
	echo "End time: `date`" | tee -a ${LOGFILE}
fi

# BUILD REFERENCE GENOME, if $build_ref_genome == true:

if [ "$build_ref_genome" == "true" ]; then
	# activate environment. Since the command conda activate doesn't (always?) work
	# in subshell, we first want to use source to make the command available:
	path_to_conda_sh=$(conda info --base)/etc/profile.d/conda.sh
	source $path_to_conda_sh 
	# now we can activate environment
	echo "Activating environment...." | tee -a ${LOGFILE}
	conda activate $path_to_env # this cannot be put into LOGFILE, because then the conda environment is not properly activated for some reason.
	# now start building the reference genome!
	# create (if not there yet) and cd into refgenomes folder;
	if ! [ -d refgenomes ]; then
		mkdir refgenomes
	fi
	cd refgenomes
	echo "Currently working in folder `pwd`" | tee -a ${LOGFILE}
	# now run the script to build the genome:
	echo "We will now start building the reference genome, using the script $script_dir/src/create_cellranger_ref_from_ensembl.sh" | tee -a ${LOGFILE}
	echo "This might take a few hours. Start time: `date`" | tee -a ${LOGFILE}
	echo "For a detailed log of the genome building, check out the logfile in your ${work_dir}/refgenomes folder!" | tee -a ${LOGFILE}
	if [ "$incl_sarscov2" == "false" ]; then
		if [ "$download_ensembl_files" == "true" ]; then
			# -d default true, u true
			${script_dir}/src/create_cellranger_ref_from_ensembl.sh -e ${ensrel} -g ${genomestring} -s ${species} -c ${expectedcrv} -t ${nthreads} -m ${memgb} -u true -o ${work_dir}/refgenomes | tee -a ${LOGFILE}
		else
			# -d to false
			${script_dir}/src/create_cellranger_ref_from_ensembl.sh -e ${ensrel} -g ${genomestring} -s ${species} -c ${expectedcrv} -t ${nthreads} -m ${memgb} -d false -o ${work_dir}/refgenomes | tee -a ${LOGFILE}
		fi
		# check md5sum if default parameters were used:
		if [ "${genomestring}" == "GRCh38" ] && [ "${ensrel}" == "99" ] && [ "${species}" == "homo_sapiens" ] && [ "${expectedcrv}" == "3.1.0" ]; then
			echo "Checking md5sum of output folder..." | tee -a ${LOGFILE}
			md5sum -c $script_dir/src/refgenomes_md5checks/homo_sapiens_GRCh38_ensrel99_cr3.1.0.md5 | tee -a ${LOGFILE}
		fi
	elif [ "$incl_sarscov2" == "true" ]; then
		echo "Including Sars-cov2 genome into the reference..." | tee -a ${LOGFILE}
		if [ "$download_ensembl_files" == "true" ]; then
			# -d default true, u true
			$script_dir/src/create_cellranger_ref_from_ensembl.sh -e ${ensrel} -g ${genomestring} -s ${species} -c ${expectedcrv} -t ${nthreads} -m ${memgb} -u true -n sars_cov2 -f $script_dir/res/sars_cov2_genome/sars_cov2_genome.gtf -a $script_dir/res/sars_cov2_genome/sars_cov2.fasta -o ${work_dir}/refgenomes | tee -a ${LOGFILE}
		else
			# -d to false
			$script_dir/src/create_cellranger_ref_from_ensembl.sh -e ${ensrel} -g ${genomestring} -s ${species} -c ${expectedcrv} -t ${nthreads} -m ${memgb} -d false -n sars_cov2 -f $script_dir/res/sars_cov2_genome/sars_cov2_genome.gtf -a $script_dir/res/sars_cov2_genome/sars_cov2.fasta -o ${work_dir}/refgenomes | tee -a ${LOGFILE}
		fi
		# check md5sum if default parameters were used:
		if [ ${genomestring} == "GRCh38" ] && [ "${ensrel}" == "99" ] && [ "${species}" == "homo_sapiens" ] && [ "${expectedcrv}" == "3.1.0" ]; then
			echo "Checking md5sum of output folder..." | tee -a ${LOGFILE}
			md5sum -c $script_dir/src/refgenomes_md5checks/homo_sapiens_GRCh38_ensrel99_cr3.1.0_sars_cov2.md5 | tee -a ${LOGFILE}
		fi
	fi
	echo "End time: `date`" | tee -a ${LOGFILE}
fi

echo 'End of script.' | tee -a ${LOGFILE}
