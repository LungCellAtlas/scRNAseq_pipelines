#!/bin/bash
# A: Lisa Sikkema, 2020
# D: testrun Lung Cell Atlas cellranger pipeline


# parameter defaults: 

# number of cores for cellranger (-c flag)
localcores="24"
# number of cores for samtools (-t flag)
samtools_thr="12"
# memory in GB (-m flag)
localmemGB="80"

# set required parameters from optional flag arguments to "", so that later on we can check if an actual argument was passed:
# profile (-p flag)
profile=""
# conda env path (-e flag)
conda_env_dir_path=""
# sitename (-s flag)
sitename=""
# path to lftp executable (-l flag)
lftp_path=""
# secure directory name (-d flag):
secure_dir_name=""

# clusterOptions:
ClusterOptions=""
# queue
queue=""

# environment name for check of path:
env_name="cr3-velocyto-scanpy"




usage() {
	cat <<HELP_USAGE
	NOTE: this script should only be run from a secure environment, since it will transfer files through sftp to a secure Helmholtz server!
	NOTE 2: this script should be run from the parent directory of your downloaded sc_processing_cellranger directory!


	Usage: $(basename "$0") [-hpesldcmtqC]
		-h 				show this help message

 		Mandatory arguments:
 		-p <cluster|local> 		"Profile" for computation. Must be set to either 
 						local or cluster. Use local if pipeline can be 
 						run on current machine. Use cluster if jobs need 
 						to be submitted to cluster. See -q and -C flag 
 						below for further explanation about cluster 
 						profile.
 		-e <path_to_conda_environment> 		path to the directory of 
 						$env_name conda environment that was installed 
 						previously. Should end with "$env_name"
 		-s <sitename> 			name of your site/instute, upper case: e.g. 
						SANGER or HELMHOLTZ. This string will be used 
						for naming the output file of the testrun, which 
						will automatically be transfered to the Helmholtz 
						server.
 		-l <path_to_lftp> 		path to lftp executable (installation 
						instructions on Lung Cell Atlas GitHub 
						(https://github.com/LungCellAtlas/data_sharing/blob/master/README.md)) 
						lftp is needed to securely transfer your pipeline 
						output the the Helmholtz server
 		-d <secure_dir_name>		directory name of secure dictory on 
						Helmholtz server: this should have been provided 
						to you by your Helmholtz contact person. The 
						name of the folder is needed to get access to 
						the Helmholtz sever directory and deposit the 
						output of your testrun.

 		Optional arguments specifying resources:
 		-c <n_cores_cr>			number of cores to be used by cellranger 
 						(default: ${localcores})
 		-m <Gb_mem_cr>			memory in Gb to be used by CellRanger 
 						(default: ${localmemGB})
 		-t <n_cores_st>			number of cores to be used by samtools, this 
						should be lower than the total number of cores 
						used by cellranger (default: ${samtools_thr})

 		Optional arguments if profile (-p) is set to cluster, and if cluster is 
 		a SLURM cluster. (If cluster is not SLURM, please visit the nextflow 
 		documentation (https://www.nextflow.io/docs/latest/executor.html) for 
 		other executors and edit the 
 		[...]/sc_processing_cellranger/nfpipeline/nextflow.config file 
 		accordingly.):
 		-q <que_name>			queue. Name of the queue/partition to be used.
 		-C <cluster_options>		ClusterOptions: additional parameters added 
						for submitting the processes, as string, e.g. 
						'qos=icb_other --nice=1000'. Please note: if you 
						want to pass parameters to -C that start with --, 
						then please do not use -- for the first instance, 
						this will be added automatically. e.g. use: 
						-C 'qos=icb_other --nice=1000', so that 
						'--qos=icb_other --nice=1000' will be passed to 
						SLURM.

HELP_USAGE
}

# go through optional arguments:
# preceding colon after getopts: don't allow for any automated error messages
# colon following flag letter: this flag requires an argument
while getopts ":hp:e:s:l:d:c:m:t:q:C:" opt; do
	# case is bash version of 'if' that allows for multiple scenarios
	case "$opt" in
		# if h is added, print usage and exit
		h ) usage
			exit
			;;
		p ) profile=$OPTARG
			;;
		e ) conda_env_dir_path=$OPTARG
			;;
		s ) sitename=$OPTARG
			;;
		l ) lftp_path=$OPTARG
			;;
		d ) secure_dir_name=$OPTARG
			;;
		c ) localcores=$OPTARG
			;;
		m ) localmemGB=$OPTARG
			;;
		t ) samtools_thr=$OPTARG
			;;
		q ) queue=$OPTARG
			;;
		C ) ClusterOptions=$OPTARG
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


# check if necessary arguments were provided and extra sanity checks:
echo "Checking if all necessary arguments were passed..." 

# profile
if [[ $profile != cluster ]] && [[ $profile != local ]]; then
	echo "-p [profile] argument should be set to either local or cluster! Exiting."
	exit 1
fi
# conda env path:
# check if argument was passed:
if [ -z $conda_env_dir_path ]; then
	echo "No path to the directory of the conda environment $env_name was passed under flag -e."
	echo "Exiting."
	exit 1
fi
# check if path leads to directory
if ! [ -d $conda_env_dir_path ]; then
	echo "conda environment path is not a directory. Exiting."
	exit 1
fi
# check if path ends with correct environment name:
if ! [[ $conda_env_dir_path == *$env_name ]]; then
	echo "Environment name (path to conda environment under flag -e) does not end with $env_name. Exiting."
	exit 1
fi
# check if sitename was provided:
if [ -z $sitename ]; then
	echo "No sitename provided. Sitename should be provided under flag -s. Exiting."
	exit 1
else
	# convert to uppercase:
	sitename=${sitename^^}
fi
# lftp path:
# check if argument was passed:
if [ -z $lftp_path ]; then
	echo "No lftp path was provided. Path to lftp should be provided under flag -l. Exiting."
	exit 1
	# check if path leads to file:
elif ! [ -f $lftp_path ]; then
	echo "The provided lftp path (flag -l) does not lead to a file. Exiting."
	exit 1
elif ! [ -x $lftp_path ]; then
	echo "The provided lftp path does not lead to an executable file. Exiting."
	exit 1
fi
# directory to helmholtz server:
if [ -z $secure_dir_name ]; then
	echo "No name of secure directory provided (flag -d). Exiting."
	exit 1
fi

# check if script is run from a secure server:
# let user confirm parameters:
read -r -p "Note: this script should be run from a secure server/machine, since it will connect to a helmholtz server through sftp. Are you working from a secure environment? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
    echo "Secure environment confirmed."
else
    echo "Not working from a secure environment. Exiting."
	exit 1
fi

# check if directory run/testrun already exists
if [ -d sc_processing_cellranger/testrun ]; then
	echo "directory './sc_processing_cellranger/testrun' already exists. Please remove testrun directory. Exiting."
	exit 1
fi




# Log filenname
LOGFILE="LCA_pipeline_testrun.log"
# check if logfile already exists:
if [ -f ${LOGFILE} ]; then
    echo "ERROR: LOG file ${LOGFILE} already exists. please remove. exit."
    exit 1
fi

# if a secure-directory name is provided, try to enter directory...
echo "checking if provided Helmholtz secure server directory name (flag -d) leads to directory..." | tee -a ${LOGFILE}

# don't know how to automate this...
(
echo cd $secure_dir_name
) | $lftp_path -p 21021 ftp://ftpexchange.helmholtz-muenchen.de 

echo "NOTE: if 'Access Failed' message was printed above, exit and make sure your directory name is corrected (-d flag)!" | tee -a ${LOGFILE}


# print parameters. tee command (t-split) splits output into normal printing and a second target, 
# in this case the log file to which it will -a(ppend) the output.
# i.e. parameters are printed and stored in logfile.
echo "Params:" | tee -a ${LOGFILE}
echo "n cores for cellranger: ${localcores}, n cores for samtools: ${samtools_thr}, localmemGB: ${localmemGB}" | tee -a ${LOGFILE}
echo "profile: ${profile}" | tee -a ${LOGFILE}
echo "sitename provided: ${sitename}" | tee -a ${LOGFILE}
echo "path to conda environment directory provided: ${conda_env_dir_path}" | tee -a ${LOGFILE}

# let user confirm parameters:
read -r -p "Are the parameters correct? Continue? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
    echo "Parameters confirmed." | tee -a ${LOGFILE}
else
    echo "Parameters not confirmed, exit." | tee -a ${LOGFILE}
	exit 1
fi


# cd into sc_processing_cellranger folder
cd sc_processing_cellranger

# print present working directory, it should be sc_processing_cellranger
echo "Current working directory should be sc_processing_cellranger" | tee -a ../${LOGFILE}
echo "pwd: `pwd`" | tee -a ../${LOGFILE}

# creating directory for testrun now:
mkdir -p testrun/run
echo "directory for testrun created: `pwd`/testrun/run" | tee -a ../${LOGFILE}

# cd into testrun directory
cd testrun/run

# activate environment. Since the command conda activate doesn't (always?) work
# in subshell, we first want to use source:
path_to_conda_sh=$(conda info --base)/etc/profile.d/conda.sh
source $path_to_conda_sh 
# now we can activate environment
echo "Activating conda environment...." | tee -a ../../../${LOGFILE}
conda activate $conda_env_dir_path # this cannot be put into LOGFILE, because then the conda environment is not properly activated for some reason.

# prepare extra arguments for nextflow command
nf_add_arguments=""
if ! [ -z $queue ]; then
	nf_add_arguments="--queue ${queue}"
fi
if ! [ -z "$ClusterOptions" ]; then
	nf_add_arguments="${nf_add_arguments} --clusterOpt '${ClusterOptions}'"
fi
# now run nextflow command:
echo "Running nextflow command now.... Start time nf run: `date`" | tee -a ../../../${LOGFILE}
# try running nextflow from subshell...
(
nextflow run ../../nfpipeline/sc_processing_r7.nf -profile $profile -c ../../nfpipeline/nextflow.config --outdir '../' --samplesheet '../../samplefiles/Samples_testdata.xls' --condaenvpath $conda_env_dir_path --localcores $localcores --localmemGB $localmemGB --samtools_thr $samtools_thr -bg "$nf_add_arguments"
) | tee -a ../../../${LOGFILE} 
echo "Done. End time nf run: `date`" | tee -a ../../../${LOGFILE}

# move back to root folder
cd ../..
# and zip the result of the testrun:
echo "Compressing the output of your testrun into the file $sitename.testrun.tar.gz..." | tee -a ../${LOGFILE}
tar -czvf $sitename.testrun.tar.gz --exclude='*.bam' --exclude='*.bai' --exclude './*/run' ./testrun | tee -a ../${LOGFILE}
echo "Done" | tee -a ../${LOGFILE}


# connect to remote server and transfer files through sftp secure file transfer
# prepare folder name (`date` command doesn't work on remote server)
date_today_long=`date '+%Y%m%d_%H%M'`
target_dir=testrun_${sitename}_$date_today_long
# pipe lines into lftp server command line:
(
cat << EOF
cd $secure_dir_name
mkdir $target_dir
cd $target_dir 
echo "Depositing files in folder with name $target_dir on lftp server."
put $sitename.testrun.tar.gz 
echo "Done"
EOF
) | $lftp_path -p 21021 ftp://ftpexchange.helmholtz-muenchen.de | tee -a ../${LOGFILE}


echo "End of script!" | tee -a ../${LOGFILE}

