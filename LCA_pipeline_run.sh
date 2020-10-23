#!/bin/bash
# A: Lisa Sikkema, 2020
# D: run Lung Cell Atlas cellranger pipeline

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
# dataset name (-n flag)
dataset_name=""
# output directory
out_dir=""
# upload files to Helmholtz secure folder, boolean:
upload=""
# clusterOptions:
ClusterOptions=""
# queue
queue=""
# path to xls file with sample info:
path_to_sample_table=""
# upload link to Helmholtz NextCloud secure storage:
upload_link=""



usage() {
	cat <<HELP_USAGE

	Lung Cell Atlas pipeline version: v${pipeline_version}


	Usage: $(basename "$0") [-hpesnulxocmtqC]
		
		-h 				show this help message

 		Mandatory arguments:
 		
 		-p <cluster|local> 		"Profile" for computation. Must be set to either 
 						local or cluster. Use local if complete script can be 
 						run on current machine. Use cluster if jobs need 
 						to be submitted to cluster from within the script. 
 						See -q and -C flag below for further explanation about 
 						cluster profile.
 		
 		-e <path_to_conda_environment> 	Path to the directory of $env_name 
 						conda environment that was installed 
 						previously. Should end with "$env_name"
 		
 		-s <sitename> 			Name of your site/instute, upper case: e.g. 
						SANGER or HELMHOLTZ. This string will be used 
						for naming the output file of the testrun, which 
						will automatically be transfered to the Helmholtz 
						server if -u is set to "true".
		
		-n <dataset_name>		Name of dataset. This will be added to the
						output file name, so that identity of file is clear. 
		
		-u <true|false>			Whether to automatically upload the testrun 
						output to the the Helmholtz secure server
		
		-l <upload_link> 		Only mandatory if u==true. Link that
						is needed to upload the pipeline output (excluding 
						.bam and .bai files) to secure Helmholtz storage.
						This link will be provided to you by your LCA 
						contact person. 

		-x <path_to_sample_table_file>	Path to the file that contains a table
						with the required sample information. For more detailed
						instructions on what the file should look like, 
						check the LCA_pipeline GitHub Readme.
						Alternatively, and if you have run the pipeline 
						testrun script before, you can check out the example
						file in its output directory, named 
						Samples_testdata_testrun.txt

		-o <output_dir_name>		Path to output directory specific for this dataset,
						in which to store the output of the pipeline run. 

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
 		other executors and edit the [...]/conf/nextflow.config file 
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
while getopts ":hp:e:s:n:c:m:t:q:u:l:x:o:C:" opt; do
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
		n ) dataset_name=$OPTARG
			;;
		c ) localcores=$OPTARG
			;;
		m ) localmemGB=$OPTARG
			;;
		t ) samtools_thr=$OPTARG
			;;
		q ) queue=$OPTARG
			;;
		u ) upload=$OPTARG
			;;
		l ) upload_link=$OPTARG
			;;
		o ) out_dir=$OPTARG
			;;
		x ) path_to_sample_table=$OPTARG
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
# check if dataset name was provided:
if [ -z $dataset_name ]; then
	echo "No dataset name provided. Dataset_name should be provided under flag -n. Exiting."
	exit 1
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

# check if output dir was provided:
if [ -z $out_dir ]; then 
	echo "No output directory was provided under flag -o. Exiting"
	exit 1
fi
# check if output dir is a directory:
if ! [ -d $out_dir ]; then
	echo "output dir $out_dir is not a directory. Exiting."
	exit 1
fi
# check if out_dir has trailing slash, and remove it if it's there:
if [[ $out_dir == *"/" ]]; then
	echo "removing trailing slash from out_dir."
	out_dir=${out_dir::-1}
fi

# check if argument was provided for path to sample.xls file
if [ -z $path_to_sample_table ]; then
	echo "no argument was provided for the -x flag. It should be set to the path for your sample.xls file. Exiting."
	exit 1
fi
# if an argument was provided, check if it leads to an actual file:
if ! [ -f $path_to_sample_table ]; then
	echo "path to sample.xls file provided under -x flag does not lead to a file. Please correct path. Exiting."
	exit 1
fi


# store path where current script is located as script_dir
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# cd into output directory
cd $out_dir
# store full path of output directory (in case out_dir was only relative path)
out_dir=`pwd`


# check if run directory already exists in out_dir:
if [ -d pipelinerun_v${pipeline_version} ]; then
	echo "There is already a directory named 'pipelinerun_v${pipeline_version}' in your outdir '${out_dir}'! Remove it or change out_dir under flag -o. Exiting."
	exit 1
fi
# create directory called pipelinerun_v${pipeline_version}/run and cd into it
echo "creating directory 'pipelinerun_v${pipeline_version}' in output directory" 
mkdir -p pipelinerun_v${pipeline_version}/run
cd pipelinerun_v${pipeline_version}

# Log filenname
logfile_dir=`pwd`
LOGFILE=$logfile_dir/LOG_LCA_pipeline_run.log

# check if logfile already exists:
if [ -f ${LOGFILE} ]; then
    echo "ERROR: LOG file ${LOGFILE} already exists. please remove. exiting." 
    exit 1
else
	echo "Creating log file in ${LOGFILE}"
	echo `date` > ${LOGFILE}
fi
# print pipeline version
echo "Lung Cell Atlas pipeline version: v${pipeline_version}" | tee -a ${LOGFILE}

# print parameters. tee command (t-split) splits output into normal printing and a second target, 
# in this case the log file to which it will -a(ppend) the output.
# i.e. parameters are printed and stored in logfile.
echo "PARAMETERS:" | tee -a ${LOGFILE}
echo "upload output files to Helmholtz server automatically: ${upload}" | tee -a ${LOGFILE}
echo "n cores for cellranger: ${localcores}, n cores for samtools: ${samtools_thr}, localmemGB: ${localmemGB}" | tee -a ${LOGFILE}
echo "profile: ${profile}" | tee -a ${LOGFILE}
echo "output dir: ${out_dir}" | tee -a ${LOGFILE}
echo "file with sample information: ${path_to_sample_table}" | tee -a ${LOGFILE}
echo "sitename: ${sitename}" | tee -a ${LOGFILE}
echo "dataset name: ${dataset_name}" | tee -a ${LOGFILE}
echo "path to conda environment directory: ${conda_env_dir_path}" | tee -a ${LOGFILE}

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


# now move into run directory, for nextflow command:
cd run
# prepare extra arguments for nextflow command
nf_add_arguments=""
if ! [ -z $queue ]; then
	nf_add_arguments="--queue ${queue} "
fi
if ! [ -z "$ClusterOptions" ]; then
	nf_add_arguments="${nf_add_arguments}--clusterOpt '${ClusterOptions}'"
fi
# now run nextflow command:
echo "Running nextflow command now, this will take a while.... Start time nf run: `date`" | tee -a ${LOGFILE}
# run nextflow from subshell, so that we can still push it to bg if we want, and store the output
(
nextflow run $script_dir/src/sc_processing_r7.nf -profile $profile -c $script_dir/conf/nextflow.config --outdir $out_dir/pipelinerun_v${pipeline_version}/ --samplesheet $path_to_sample_table --condaenvpath $conda_env_dir_path --localcores $localcores --localmemGB $localmemGB --samtools_thr $samtools_thr -bg "$nf_add_arguments"
) | tee -a ${LOGFILE}
echo "Done. End time nf run: `date`" | tee -a ${LOGFILE}
# check if run was successfull. In that case, there should be a cellranger directory in the testrun directory
if ! [ -d $out_dir/pipelinerun_v${pipeline_version}/cellranger ]; then
	echo "Something must have gone wrong with your nextflow run. No cellranger directory was created. Exiting." | tee -a ${LOGFILE}
	exit 1
else
	echo "Ok" | tee -a ${LOGFILE}
fi


# move back to out_dir
cd $out_dir

# and zip the result of run. Include the date and time in the file name, 
# so we can distinguish between different testruns.
date_today_long=`date '+%Y%m%d_%H%M'`
echo "Compressing the output of your pipeline run into the file: \
$out_dir/${sitename}_${dataset_name}_${date_today_long}.pipelinerun_v${pipeline_version}.tar.gz \
excluding .bam and .bai files, and excluding ./run direcory..." | tee -a ${LOGFILE}
# note that folder names/paths are considered relative to the folder to tar. 
# so --exlude=run actually means --exclude=$outdir_full/pipelinerun_v${pipeline_version}/run!
tar --exclude="*.bam" --exclude="*.bai" --exclude=run -czvf ${sitename}_${dataset_name}_${date_today_long}.pipelinerun_v${pipeline_version}.tar.gz  "$out_dir/pipelinerun_v${pipeline_version}" | tee -a ${LOGFILE}
echo "Done" | tee -a ${LOGFILE}
# move tarred file to output directory that was tarred
mv ${sitename}_${dataset_name}_${date_today_long}.pipelinerun_v${pipeline_version}.tar.gz $out_dir/pipelinerun_v${pipeline_version}/

# now upload the output to Helmholtz Nextcloud, if -u was set to true
if [[ $upload == true ]]; then
	echo "We will now upload output to Helmholtz secure folder" | tee -a ${LOGFILE}
	$script_dir/src/cloudsend.sh $out_dir/pipelinerun_v${pipeline_version}/${sitename}_${dataset_name}_${date_today_long}.pipelinerun_v${pipeline_version}.tar.gz $upload_link 2>&1 | tee -a ${LOGFILE} # redirect output of shellscript to logfile
fi

# end
echo "End of script!" | tee -a ${LOGFILE}

