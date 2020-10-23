#!/bin/bash
# A: Lisa Sikkema, 2020
# D: testrun Lung Cell Atlas cellranger pipeline

# LCA pipeline version:
pipeline_version="0.1.0"

# parameter defaults: 

# number of cores for cellranger (-c flag)
localcores="24"
# number of cores for samtools (-t flag)
samtools_thr="12"
# memory in GB (-m flag)
localmemGB="80"
# environment name for check of path:
env_name="cr3-velocyto-scanpy"


# set required parameters from optional flag arguments to "", so that later on we can check if an actual argument was passed:
# profile (-p flag)
profile=""
# conda env path (-e flag)
conda_env_dir_path=""
# sitename (-s flag)
sitename=""
# upload files to Helmholtz secure folder, boolean:
upload=""
# output directory
out_dir=""
# clusterOptions:
ClusterOptions=""
# queue
queue=""
# upload link to Helmholtz NextCloud secure storage:
upload_link=""


usage() {
	cat <<HELP_USAGE

	LCA pipeline version: ${pipeline_version}
	
	Usage: $(basename "$0") [-hpesulowcmtqC]
		
		-h 				show this help message

 		
 		Mandatory arguments:
 		
 		-p <cluster|local> 		"Profile" for computation. Must be set to either 
 						local or cluster. Use local if pipeline can be 
 						run on current machine. Use cluster if jobs need 
 						to be submitted to cluster within the script. 
 						See -q and -C flag below for further explanation 
 						about cluster profile.
 		
 		-e <path_to_conda_environment> 	Path to the directory of 
 						$env_name conda environment that was installed 
 						previously. Should end with "$env_name"
 		
 		-s <sitename> 			Name of your site/instute: e.g. Sanger 
 						or Helmholtz. This string will be used for 
 						naming the output file of the testrun, which 
						will automatically be transfered to the Helmholtz 
						server if -u is set to "true".
		
		-u <true|false>			Whether to automatically upload the testrun 
						output to the the Helmholtz secure server
		
		-l <upload_link> 		Only mandatory if u==true. Link that
						is needed to upload the pipeline output (excluding 
						.bam and .bai files) to secure Helmholtz storage.
						This link will be provided to you by your LCA 
						contact person.

		-o <out_dir>			Path to output directory in which the output 
						of the testrun will be stored. (This can be the same
						as the work_dir (-w), if wanted.)

		-w <work_dir>			Path to working directory as used for pipeline
						setup. This directory contains the reference genome 
						that was built in the refgenomes dir as well as the data 
						for the testrun in the testdata dir

 		Optional arguments specifying resources:
 		
 		-c <n_cores_cr>			Number of cores to be used by cellranger 
 						(default: ${localcores})
 		
 		-m <Gb_mem_cr>			Memory in Gb to be used by CellRanger 
 						(default: ${localmemGB})
 		
 		-t <n_cores_st>			Number of cores to be used by samtools, this 
						should be lower than the total number of cores 
						used by cellranger (default: ${samtools_thr})

 		Optional arguments if profile (-p) is set to cluster, and if cluster is 
 		a SLURM cluster. (If cluster is not SLURM, please visit the nextflow 
 		documentation (https://www.nextflow.io/docs/latest/executor.html) for 
 		other executors and edit the ./conf/nextflow.config file 
 		accordingly.):
 		
 		-q <que_name>			Queue. Name of the queue/partition to be used.
 		
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
# colon following flag letter: this flag takes in an argument
while getopts ":hp:e:s:u:l:o:w:c:m:t:q:C:" opt; do
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
		u ) upload=$OPTARG
			;;
		l ) upload_link=$OPTARG
			;;
		o ) out_dir=$OPTARG
			;;
		w)  work_dir=$OPTARG
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

# store folder in which current script is located 
test_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# store parent dir as script_dir
cd ${test_dir}
cd ..
script_dir=`pwd`



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
# check if -u argument is either true or false.
# first check if any argument was provided:
if [ -z $upload ]; then
	echo "no argument was provided under the -u flag. it should be set to either true or false."
	echo "Exiting."
	exit 1
fi
# if there is a -u argument provided, convert it to lowercase
upload="${upload,,}"
if [ $upload != true ] && [ $upload != false ]; then
	echo "-u flag can only be set to 'true' or 'false'! exiting."
	exit 1
fi
# if -u is true, check if upload link was provided:
if [ $upload == true ] && [ -z $upload_link ]; then
	echo "-u is set to true, but no upload link was provided under -l. Exiting."
	exit 1
fi

# check if argument was provided for -o flag
if [ -z $out_dir ]; then
	echo "no argument for output directory was provided under -o flag. Exiting."
	exit 1
fi
# check if output dir is a directory:
if ! [ -d $out_dir ]; then
	echo "output dir $out_dir as provided under -o flag is not a directory. Exiting."
	exit 1
fi
# check if outdir has trailing slash, and remove it if it's there:
if [[ $out_dir == *"/" ]]; then
	echo "removing trailing slash from outdir."
	out_dir=${out_dir::-1}
fi
# # check if directory testrun_v${pipeline_version} already exists
if [ -d $out_dir/testrun_v${pipeline_version} ]; then
	echo "directory '${out_dir}/testrun_v${pipeline_version}' already exists. Please remove testrun_v${pipeline_version} directory. Exiting."
	exit 1
fi

# check if working directory argument was passed:
if [ -z $work_dir ]; then
	echo "no argument for work directory was provided under -w flag. Exiting."
	exit 1
fi
# check if work dir is a directory
if ! [ -d $work_dir ]; then
	echo "work dir $work_dir as provided under -w flag is not a directory. Exiting."
	exit 1
fi
# check if workdir has trailing slash, and remove it if it's there:
if [[ $work_dir == *"/" ]]; then
	echo "removing trailing slash from work dir."
	work_dir=${work_dir::-1}
fi
# check if work dir has folders refgenomes and testdata
if ! [ -d $work_dir/refgenomes ]; then
	echo "work dir $work_dir as provided under -w flag has no subdirectory named 'refgenomes'."
	echo "Make sure the workdirectory corresponds to the work directory provided during pipeline setup."
	echo "This is the folder where the refgenome was built. Exiting."
	exit 1
fi
if ! [ -d $work_dir/testdata ]; then
	echo "work dir $work_dir as provided under -w flag has no subdirectory named 'testdata'."
	echo "Make sure the workdirectory corresponds to the work directory provided during pipeline setup."
	echo "This is the folder in which the testdata were downloaded. Exiting."
	exit 1
fi

# cd into out_dir
cd $out_dir
# store full path of out_dir
out_dir=`pwd`
# creating directory for testrun now:
mkdir -p testrun_v${pipeline_version}/run
echo "directory for testrun created: $out_dir/testrun_v${pipeline_version}/run"

# cd into testrun_v${pipeline_version} directory
cd testrun_v${pipeline_version}

# Log filenname
logfile_dir=`pwd`
LOGFILE=$logfile_dir/LOG_LCA_pipeline_testrun.log

# check if logfile already exists:
if [ -f ${LOGFILE} ]; then
    echo "ERROR: LOG file ${LOGFILE} already exists. please remove. exit."
    exit 1
else
	# Create log file and add DATE
	echo `date` > ${LOGFILE}
	echo "LOG created under ${LOGFILE}"
fi
# echo pipeline version:
echo "Lung Cell Atlas pipeline version: ${pipeline_version}" | tee -a ${LOGFILE}

# print parameters. tee command (t-split) splits output into normal printing and a second target, 
# in this case the log file to which it will -a(ppend) the output.
# i.e. parameters are printed and stored in logfile.
echo "PARAMETERS:" | tee -a ${LOGFILE}
echo "upload output files to Helmholtz server automatically: ${upload}" | tee -a ${LOGFILE}
echo "n cores for cellranger: ${localcores}, n cores for samtools: ${samtools_thr}, localmemGB: ${localmemGB}" | tee -a ${LOGFILE}
echo "profile: ${profile}" | tee -a ${LOGFILE}
echo "sitename: ${sitename}" | tee -a ${LOGFILE}
echo "path to conda environment directory: ${conda_env_dir_path}" | tee -a ${LOGFILE}
echo "out_dir (testdir appended): $out_dir/testrun_v${pipeline_version}" | tee -a ${LOGFILE}
echo "work_dir: $work_dir" | tee -a ${LOGFILE}

# let user confirm parameters:
read -r -p "Are the parameters correct? Continue? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
    echo "Parameters confirmed." | tee -a ${LOGFILE}
else
    echo "Parameters not confirmed, exit." | tee -a ${LOGFILE}
	exit 1
fi



# activate environment. Since the command conda activate doesn't (always?) work
# in subshell, we first want to use source:
path_to_conda_sh=$(conda info --base)/etc/profile.d/conda.sh
source $path_to_conda_sh 
# now we can activate environment
echo "Activating conda environment...." | tee -a ${LOGFILE}
conda activate $conda_env_dir_path # this cannot be put into LOGFILE, because then the conda environment is not properly activated for some reason.

# cd into "run" subdirectory for nextflow run
cd run
# prepare file with sample name and info, by replacing the "{workdir}" string with our actual work_dir,
# and storing the result in a new textfile:
sed "s|{workdir}|${work_dir}|g" $script_dir/test/Samples_testdata_template.xls > $out_dir/testrun_v${pipeline_version}/Samples_testdata_testrun.txt | tee -a ${LOGFILE}
echo "Using $out_dir/testrun_v${pipeline_version}/Samples_testdata_testrun.txt as sample file." | tee -a ${LOGFILE}
# prepare extra arguments for nextflow command
nf_add_arguments=""
if ! [ -z $queue ]; then
	nf_add_arguments="--queue ${queue}"
fi
if ! [ -z "$ClusterOptions" ]; then
	nf_add_arguments="${nf_add_arguments} --clusterOpt '${ClusterOptions}'"
fi
# now run nextflow command:
echo "Running nextflow command now, this will take a while.... Start time nf run: `date`" | tee -a ${LOGFILE}
# run nextflow from subshell, so that we can push it to bg without problems if we want. Output is still added to Log
(
nextflow run $script_dir/src/sc_processing_r7.nf -profile $profile -c $script_dir/conf/nextflow.config --outdir $out_dir/testrun_v${pipeline_version}/ --samplesheet $out_dir/testrun_v${pipeline_version}/Samples_testdata_testrun.txt --condaenvpath $conda_env_dir_path --localcores $localcores --localmemGB $localmemGB --samtools_thr $samtools_thr -bg "$nf_add_arguments"
) | tee -a ${LOGFILE}
echo "Done. End time nf run: `date`" | tee -a ${LOGFILE}
# check if run was successfull. In that case, there should be a cellranger directory in the testrun_v${pipeline_version} directory
if ! [ -d $out_dir/testrun_v${pipeline_version}/cellranger ]; then
	echo "Something must have gone wrong with your nextflow run. No cellranger directory was created in your outdir. Exiting." | tee -a ${LOGFILE}
	exit 1
else
	echo "Ok" | tee -a ${LOGFILE}
fi
# check md5sum of output .mtx, and barcodes and features .tsvs. (h5 and h5ad have timestamps and therefore
# cannot be used for checksums. Loom files also get prefix in indices)
echo "We will now do an md5sum check on cellranger output:" | tee -a ${LOGFILE}
md5sum -c $work_dir/testdata/CHECKSUM_testrun | tee -a ${LOGFILE}

# move back to out_dir
cd $out_dir
# and zip the result of the testrun. Include the date and time in the file name, 
# so we can distinguish between different testruns.
date_today_long=`date '+%Y%m%d_%H%M'`
echo "Compressing the output of your testrun_v${pipeline_version} into the file ${sitename}_${date_today_long}.testrun_v${pipeline_version}.tar.gz..." | tee -a ${LOGFILE}
echo "folder containing tar file: `pwd`" | tee -a ${LOGFILE}
# note that folder names/paths are considered relative to the folder to tar. 
# so --exlude=run actually means --exclude=./testrun_v${pipeline_version}/run, from the perspective of our current dir!
tar --exclude='*.bam' --exclude='*.bai' --exclude=run -czvf ${sitename}_${date_today_long}.testrun_v${pipeline_version}.tar.gz  $out_dir/testrun_v${pipeline_version} | tee -a ${LOGFILE}
echo "Done" | tee -a ${LOGFILE}

# move the file into the output directory (that was just tarred):
mv $out_dir/${sitename}_${date_today_long}.testrun_v${pipeline_version}.tar.gz $out_dir/testrun_v${pipeline_version}/

# now upload the output to Helmholtz Nextcloud
if [ $upload == true ]; then
	echo "We will now upload output to Helmholtz secure folder" | tee -a ${LOGFILE}
	$script_dir/src/cloudsend.sh $out_dir/testrun_v${pipeline_version}/${sitename}_${date_today_long}.testrun_v${pipeline_version}.tar.gz $upload_link 2>&1 | tee -a ${LOGFILE} # redirect output of shellscript to logfile
fi

# end
echo "End of script!" | tee -a ${LOGFILE}

