# Brain extraction shell script (SGE)
# Author: Ma Da (d.ma.11@ucl.ac.uk)
# Version 0.8_2013.08.29
# for STEPS label fusion on foler of images with registration already done

# usage: ./labfusion_batch.sh atlas $1 $2 $3 $4
# $1: folder include all the images for label fusion
# $2: atlas (in_vivo ex_vivo)
# $3: STEPS parameter k (kernel size in terms of voxel number)
# $4: STEPS parameter n (number of top ranked local atlas to select for label fusion)
# $5: file that contains other LabFusion parameters
ROOT_DIR=$(pwd)
# echo "Bash version ${BASH_VERSION}"
ATLAS=$(basename $2)
export QSUB_CMD="qsub -l h_rt=5:00:00 -pe smp 4 -R y -l h_vmem=2.5G -l tmem=2.5G -j y -S /bin/sh -b y -cwd -V -o job_output -e job_error"

# Set STEPS parameters
if [[ ! -z $3 ]] && [[ ! -z $4 ]]; then  # if STEPS parameter is set (-z: zero = not set), so ! -z = set
  export k=$3
  export n=$4
else # if [[ -z "${STEPS_PARAMETER}" ]] set default STEPS parameter to: "4 6"
  export k=5
  export n=8
fi

# Read user-defined parameters
if [ ! -z $5 ]; then # check if there is a 5th argument
  if [ -f $5 ]; then # check if the file specified by 5th argument exist
    . $5 # if file of 5th argument exist, read the parameters from the file
  fi
fi
export STEPS_PARAMETER="${k} ${n} "

echo "***********************************************"
echo "*   batch STEPS label fusion (STEPS) ${k} ${n}  *"
echo "***********************************************" 
# begin parcellation and dice score calculation
for H in `ls $1`
do
  TEST_NAME=`echo "$H" | cut -d'.' -f1`
  jid_LabFusion=labfusion_"$$"
  ${QSUB_CMD} -N ${jid_LabFusion} seg_LabFusion -in label/${ATLAS}/${TEST_NAME}_label_4D.nii.gz -STEPS ${STEPS_PARAMETER} $1/$H label/${ATLAS}/${TEST_NAME}_template_4D.nii.gz -out label/${TEST_NAME}_${ATLAS}_label_STEPS_${k}_${n}.nii.gz
done
  