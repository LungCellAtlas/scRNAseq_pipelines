#!/bin/bash
# A: Thomas Walzthoeni, 2020
# D: create reference files using an arbitrary Ensembl release
# D: Script based on https://support.10xgenomics.com/single-cell-gene-expression/software/release-notes/build

# VERSION
VERSION="1.1"

# Parameters defaults

# Ensembl release
ensrel="99"
# Genome string
genomestring="GRCh38"
# species
species="homo_sapiens"
# Genome2 string
genomestring2=""
# species2
species2=""
# Expected cell ranger version
expectedcrv="3.1.0"
# Resources for mkref
# number of cores
nthreads="20"
# Memory in GB
memgb="48"

# Custom GTF
custgtf=""

# Custom fa
custfa=""

# Custom name to be added
custname="custom"

# Custom name to be added
force="false"



usage="$(basename "$0") [-h] -- program to create reference files for Cellranger (https://support.10xgenomics.com/single-cell-gene-expression/software/overview/welcome).

where:
    -h  show this help text
    -e  set the Ensembl release (default: ${ensrel})
    -g  genome1 release, must match with the corresponding Ensembl release (see also Ensembls fa file name for the release), use without the patch id (e.g. GRCh37; GRCh38, GRCm38) (default: ${genomestring})
    -s  species1, tested using human (use homo_sapiens) | mouse (use mus_musculus). Used to create the path to the files on Ensembl. (default: ${species})
    -x  genome2 release, must match with the corresponding Ensembl release (see also Ensembls fa file name for the release), use without the patch id (e.g. GRCh37; GRCh38, GRCm38) (default: ${genomestring2})
    -y  species2, tested using human (use homo_sapiens) | mouse (use mus_musculus). Used to create the path to the files on Ensembl. (default: ${species2})
    -c  set cellranger version that is used (program bin: cellranger) (default: ${expectedcrv})
    -t  set the number of threads to be used by cellranger mkref (default: ${nthreads})
    -m  set the memory in GB used by cellranger mkref (default: ${memgb})
    -f  add this custom gtf to the annotation of genome1 (default: ${custgtf})
    -a  add this custom fasta to the genome1 (default: ${custfa})
    -n  custom name used if fasta and gtf is provided (default: ${custname})
    -u  force: if set to true this will remove existing log file and index folder and run the indexing without the parameter check by the user (default: ${force})"

while getopts ':h:e:c:t:m:g:s:f:a:n:y:x:u:' option; do
  case "$option" in
    h) echo "$usage"
       exit
       ;;
    e) ensrel=$OPTARG
       ;;
    c) expectedcrv=$OPTARG
       ;;
    t) nthreads=$OPTARG
       ;;
    m) memgb=$OPTARG
       ;;
       
    g) genomestring=$OPTARG
       ;;
    
	s) species=$OPTARG
       ;;
	   
	f) custgtf=$OPTARG
       ;;

	a) custfa=$OPTARG
       ;;

	n) custname=$OPTARG
       ;;	   
 
	x) genomestring2=$OPTARG
       ;;

	y) species2=$OPTARG
       ;;

	u) force=$OPTARG
       ;;

    :) printf "missing argument for -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
    *)
      echo "$usage" >&2
      ;;
  esac
done
shift $((OPTIND - 1))


if [[ $custgtf != "" ]] && [[ $custfa != "" ]]; then

if [[ ${genomestring2} != "" ]]
then
# Log filenname
LOGFILE="${species}_${genomestring}_${species2}_${genomestring2}_ensrel${ensrel}_cr${expectedcrv}_${custname}.log"

# Create the genome file name
genomefn="${species}_${genomestring}"
# Create the genome2 file name
genome2fn="${species2}_${genomestring2}_ensrel${ensrel}_cr${expectedcrv}_${custname}"

else
# Log filenname
LOGFILE="${species}_${genomestring}_ensrel${ensrel}_cr${expectedcrv}_${custname}.log"

# Create the genome file name
genomefn="${species}_${genomestring}_ensrel${ensrel}_cr${expectedcrv}_${custname}"
# Create the genome2 file name
genome2fn="NA"

fi

# Set param to 1
add_fa_gtf=1

# Check if files exists
if [ ! -f $custgtf ]; then
    echo "File $custgtf not found!"
	exit 1
fi

if [ ! -f $custfa ]; then
    echo "File $custfa not found!"
	exit 1	
fi


else

if [[ ${genomestring2} != "" ]]
then
# Log filenname
LOGFILE="${species}_${genomestring}_${species2}_${genomestring2}_ensrel${ensrel}_cr${expectedcrv}.log"

# Create the genome file name
genomefn="${species}_${genomestring}"
# Create the genome2 file name
genome2fn="${species2}_${genomestring2}_ensrel${ensrel}_cr${expectedcrv}"

else
# Log filenname
LOGFILE="${species}_${genomestring}_ensrel${ensrel}_cr${expectedcrv}.log"
# Create the genome file name
genomefn="${species}_${genomestring}_ensrel${ensrel}_cr${expectedcrv}"
# Create the genome2 file name
genome2fn="NA"
fi

# Set param to 0
add_fa_gtf=0

fi

# Out folder name
if [[ ${genomestring2} != "" ]]
then
outfolder="${genomefn}_and_${genome2fn}"
else
outfolder="${genomefn}"
fi


# Check if logfile exists
if [ -f ${LOGFILE} ]; then
    
	
	if [[ ${force} != "true" ]] 
    then
	echo "ERROR: LOG file ${LOGFILE} already exists. please remove. exit."
	exit 1	
	fi
	echo "Warn: ${LOGFILE} already exists but is removed, since force is used."

fi

# Check if outdir exists
if [ -d ${outfolder} ]; then
    
	if [[ ${force} != "true" ]] 
    then
    echo "ERROR: Output directory ${outfolder} already exists. please remove. exit."	
	exit 1	
	fi
    
	echo "Warn: Output directory ${outfolder} but is removed, since force is used."
    rm -r ${outfolder}
fi

# Create log file and add DATE
echo `date` > ${LOGFILE}
echo "Version: ${VERSION}" | tee -a ${LOGFILE}
echo "Logfile: ${LOGFILE}" | tee -a ${LOGFILE}
echo "Params:" | tee -a ${LOGFILE}
echo "Expected cellranger version: ${expectedcrv}, Ensembl release: ${ensrel}, Genome release: ${genomestring}, Species: ${species}" | tee -a ${LOGFILE}
echo "Genome2 release: ${genomestring2}, Species2: ${species2}" | tee -a ${LOGFILE}
echo "Custgtf: ${custgtf}, Custom fasta: ${custfa}, Custom name: ${custname}" | tee -a ${LOGFILE}
echo "Genome1 name: ${genomefn}" | tee -a ${LOGFILE}
echo "Genome2 name: ${genome2fn}" | tee -a ${LOGFILE}
echo "Output folder name: ${outfolder}" | tee -a ${LOGFILE}
echo "nthreads: ${nthreads}, memgb: ${memgb}" | tee -a ${LOGFILE}


if [[ ${force} != "true" ]] 
then
# Check
read -r -p "Are the parameters correct? Continue? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
    echo "Parameters confirmed." | tee -a ${LOGFILE}
else
    echo "Parameters not confirmed, exit." | tee -a ${LOGFILE}
	exit 1
fi

else
echo "Parameter checking is skipped, since force is used."
fi

####

# Test for cellranger version
cellranger sitecheck > sitecheck.txt
crversion=`head -n2 sitecheck.txt | grep -oP '\\(\\K[^)]+'`

# Check
if [[ ${crversion} != "${expectedcrv}" ]]
then
echo "ERROR: Expected cell ranger version is ${expectedcrv} but current version is ${crversion}. Maybe differnet version is installed or correct environment is not activated. Exit." | tee -a ${LOGFILE}
exit 1
else
echo "Expected cell ranger version ${crversion} found." | tee -a ${LOGFILE}

# Download genome fasta file to genome fa.gz
echo "Downloading genome from: ftp://ftp.ensembl.org/pub/release-${ensrel}/fasta/${species}/dna/${species^}.${genomestring}.dna.primary_assembly.fa.gz" >> ${LOGFILE}
wget "ftp://ftp.ensembl.org/pub/release-${ensrel}/fasta/${species}/dna/${species^}.${genomestring}.dna.primary_assembly.fa.gz" -O "genome.fa.gz"
echo "done." >> ${LOGFILE}
# get CHECKSUMS file
wget "ftp://ftp.ensembl.org/pub/release-${ensrel}/fasta/${species}/dna/CHECKSUMS" -O CHECKSUMS_FASTA
# Test checksum
sum_fa=`sum "genome.fa.gz"`
valfa=`grep "$sum_fa ${species^}.${genomestring}.dna.primary_assembly.fa.gz" CHECKSUMS_FASTA | wc -l`

if [[ ${valfa} != "1" ]] 
then
echo "ERROR: Checksum $sum_fa ${species^}.${genomestring}.dna.primary_assembly.fa.gz not found in CHECKSUMS_FASTA file, exit." | tee -a ${LOGFILE}
exit 1
else
echo "Checksum $sum_fa ${species^}.${genomestring}.dna.primary_assembly.fa.gz found in CHECKSUMS_FASTA file." | tee -a ${LOGFILE}
fi

# Gunzip fasta
gunzip "genome.fa.gz"

# Add custom fasta
if [[ ${add_fa_gtf} = 1 ]]; then
echo "Adding custom fasta file ${custfa} to genome.fa" | tee -a ${LOGFILE}
cat ${custfa} >> "genome.fa"
fi


# Genome 2
if [[ ${genomestring2} != "" ]]
then
echo "Downloading genome2 from: ftp://ftp.ensembl.org/pub/release-${ensrel}/fasta/${species2}/dna/${species2^}.${genomestring2}.dna.primary_assembly.fa.gz" >> ${LOGFILE}
wget "ftp://ftp.ensembl.org/pub/release-${ensrel}/fasta/${species2}/dna/${species2^}.${genomestring2}.dna.primary_assembly.fa.gz" -O "genome2.fa.gz"
echo "done." >> ${LOGFILE}
# get CHECKSUMS file
wget "ftp://ftp.ensembl.org/pub/release-${ensrel}/fasta/${species2}/dna/CHECKSUMS" -O CHECKSUMS_FASTA
# Test checksum
sum_fa=`sum "genome2.fa.gz"`
valfa=`grep "$sum_fa ${species2^}.${genomestring2}.dna.primary_assembly.fa.gz" CHECKSUMS_FASTA | wc -l`

if [[ ${valfa} != "1" ]] 
then
echo "ERROR: Checksum $sum_fa ${species2^}.${genomestring2}.dna.primary_assembly.fa.gz not found in CHECKSUMS_FASTA file, exit." | tee -a ${LOGFILE}
exit 1
else
echo "Checksum $sum_fa ${species2^}.${genomestring2}.dna.primary_assembly.fa.gz found in CHECKSUMS_FASTA file." | tee -a ${LOGFILE}
fi

# Gunzip fasta
gunzip "genome2.fa.gz"

fi

# Download GTF
echo "Downloading gtf from: ftp://ftp.ensembl.org/pub/release-${ensrel}/gtf/${species}/${species^}.${genomestring}.${ensrel}.gtf.gz" >> ${LOGFILE}
wget "ftp://ftp.ensembl.org/pub/release-${ensrel}/gtf/${species}/${species^}.${genomestring}.${ensrel}.gtf.gz"  -O "annotation.gtf.gz"
# get CHECKSUMS file
wget "ftp://ftp.ensembl.org/pub/release-${ensrel}/gtf/${species}/CHECKSUMS"  -O CHECKSUMS_GTF

# Test checksum
sum_gtf=`sum "annotation.gtf.gz"`
valgtf=`grep "${species^}.${genomestring}.${ensrel}.gtf.gz" CHECKSUMS_GTF | wc -l`

if [[ ${valgtf} != "1" ]] 
then
echo "ERROR: Checksum $sum_gtf ${species^}.${genomestring}.${ensrel}.gtf.gz not found in CHECKSUMS_GTF file, exit." | tee -a ${LOGFILE}
exit 1
else
echo "Checksum $sum_gtf ${species^}.${genomestring}.${ensrel}.gtf.gz found in CHECKSUMS_GTF file." | tee -a ${LOGFILE}
fi

# Gunzip gtf
gunzip "annotation.gtf.gz"

# Add custom gtf
if [[ ${add_fa_gtf} = 1 ]]; then
echo "Adding custom gtf file ${custgtf} to annotation.gtf" | tee -a ${LOGFILE}
cat ${custgtf} >> "annotation.gtf"
fi


# Genome 2
if [[ ${genomestring2} != "" ]] 
then
# Download GTF
echo "Downloading gtf from: ftp://ftp.ensembl.org/pub/release-${ensrel}/gtf/${species2}/${species2^}.${genomestring2}.${ensrel}.gtf.gz" >> ${LOGFILE}
wget "ftp://ftp.ensembl.org/pub/release-${ensrel}/gtf/${species2}/${species2^}.${genomestring2}.${ensrel}.gtf.gz"  -O "annotation2.gtf.gz"
# get CHECKSUMS file
wget "ftp://ftp.ensembl.org/pub/release-${ensrel}/gtf/${species2}/CHECKSUMS"  -O CHECKSUMS_GTF

# Test checksum
sum_gtf=`sum "annotation2.gtf.gz"`
valgtf=`grep "${species2^}.${genomestring2}.${ensrel}.gtf.gz" CHECKSUMS_GTF | wc -l`

if [[ ${valgtf} != "1" ]] 
then
echo "ERROR: Checksum $sum_gtf ${species2^}.${genomestring2}.${ensrel}.gtf.gz not found in CHECKSUMS_GTF file, exit." | tee -a ${LOGFILE}
exit 1
else
echo "Checksum $sum_gtf ${species2^}.${genomestring2}.${ensrel}.gtf.gz found in CHECKSUMS_GTF file." | tee -a ${LOGFILE}
fi

# Gunzip gtf
gunzip "annotation2.gtf.gz"

fi

# Create mkgtf command
mkgtfcmd="cellranger mkgtf annotation.gtf annotation.filtered.gtf \
                 --attribute=gene_biotype:protein_coding \
                 --attribute=gene_biotype:lincRNA \
                 --attribute=gene_biotype:antisense \
                 --attribute=gene_biotype:IG_LV_gene \
                 --attribute=gene_biotype:IG_V_gene \
                 --attribute=gene_biotype:IG_V_pseudogene \
                 --attribute=gene_biotype:IG_D_gene \
                 --attribute=gene_biotype:IG_J_gene \
                 --attribute=gene_biotype:IG_J_pseudogene \
                 --attribute=gene_biotype:IG_C_gene \
                 --attribute=gene_biotype:IG_C_pseudogene \
                 --attribute=gene_biotype:TR_V_gene \
                 --attribute=gene_biotype:TR_V_pseudogene \
                 --attribute=gene_biotype:TR_D_gene \
                 --attribute=gene_biotype:TR_J_gene \
                 --attribute=gene_biotype:TR_J_pseudogene \
                 --attribute=gene_biotype:TR_C_gene"

# Write command to log file
echo "Commands:" | tee -a ${LOGFILE}
echo ${mkgtfcmd} | tee -a ${LOGFILE}

# Execute
eval ${mkgtfcmd} >> ${LOGFILE} 2>&1

# Check
if [ "$?" -ne "0" ]
then
  echo "Error: There was an error running cellranger mkgtf" | tee -a ${LOGFILE}
fi


if [[ ${genomestring2} != "" ]] 
then
# Create mkgtf command
mkgtfcmd="cellranger mkgtf annotation2.gtf annotation2.filtered.gtf \
                 --attribute=gene_biotype:protein_coding \
                 --attribute=gene_biotype:lincRNA \
                 --attribute=gene_biotype:antisense \
                 --attribute=gene_biotype:IG_LV_gene \
                 --attribute=gene_biotype:IG_V_gene \
                 --attribute=gene_biotype:IG_V_pseudogene \
                 --attribute=gene_biotype:IG_D_gene \
                 --attribute=gene_biotype:IG_J_gene \
                 --attribute=gene_biotype:IG_J_pseudogene \
                 --attribute=gene_biotype:IG_C_gene \
                 --attribute=gene_biotype:IG_C_pseudogene \
                 --attribute=gene_biotype:TR_V_gene \
                 --attribute=gene_biotype:TR_V_pseudogene \
                 --attribute=gene_biotype:TR_D_gene \
                 --attribute=gene_biotype:TR_J_gene \
                 --attribute=gene_biotype:TR_J_pseudogene \
                 --attribute=gene_biotype:TR_C_gene"

# Write command to log file
echo "Commands:" | tee -a ${LOGFILE}
echo ${mkgtfcmd} | tee -a ${LOGFILE}

# Execute
eval ${mkgtfcmd} >> ${LOGFILE} 2>&1

# Check
if [ "$?" -ne "0" ]
then
  echo "Error: There was an error running cellranger mkgtf" | tee -a ${LOGFILE}
  #exit 1
fi

fi

if [[ ${genomestring2} != "" ]] 
then

# Create ref
mkrefcmd="cellranger mkref --genome=${genomefn} \
                 --fasta=genome.fa \
                 --genes=annotation.filtered.gtf \
				 --genome=${genome2fn} \
				 --fasta=genome2.fa \
				 --genes=annotation2.filtered.gtf \
                 --memgb ${memgb} --nthreads ${nthreads} --ref-version=${crversion}"
else

# Create ref
mkrefcmd="cellranger mkref --genome=${genomefn} \
                 --fasta=genome.fa \
                 --genes=annotation.filtered.gtf \
                 --memgb ${memgb} --nthreads ${nthreads} --ref-version=${crversion}"
fi



# will create a folder with the genome name

# Write to log file
echo ${mkrefcmd} | tee -a ${LOGFILE}

# Execute
eval ${mkrefcmd} >> ${LOGFILE} 2>&1

# Check
if [ "$?" -ne "0" ]
then
  echo "Error: There was an error running cellranger mkref" | tee -a ${LOGFILE}
  #exit 1
fi

# File cleanup
rm "sitecheck.txt"
rm "CHECKSUMS_GTF"
rm "CHECKSUMS_FASTA"
rm "annotation.gtf"
rm "annotation.filtered.gtf"
rm "genome.fa"

if [[ ${genomestring2} != "" ]] 
then
rm "annotation2.gtf"
rm "annotation2.filtered.gtf"
rm "genome2.fa"
fi

# copy custom fasta and gtf
if [[ ${add_fa_gtf} = 1 ]]; then
cp ${custfa} "${outfolder}/"
cp ${custgtf} "${outfolder}/"
echo "Copied ${custfa} ${custgtf} to ${outfolder}" | tee -a ${LOGFILE}
fi

# Create md5 sums file
find "${genomefn}" -type f -exec md5sum {} \; | sort -k 2 | grep -vwE "(genes.pickle|reference.json|genomeParameters.txt)" > "${genomefn}.md5"
echo "Created ${genomefn}.md5" | tee -a ${LOGFILE}

# Append log
cat "Log.out" >> ${LOGFILE}
rm "Log.out"
echo "Done." | tee -a ${LOGFILE}
fi

