# Structural Parcellation shell script (SGE)
# Author: Ma Da (d.ma.11@ucl.ac.uk)
# Version 0.9_2013.10.21
#!/bin/bash
# echo "Bash version ${BASH_VERSION}..."

# $1: enquiry image
# $2: mask for enquiry image.  if no mask just type "no_mask"
# $3: atlas folder "in_vivo" or "ex_vivo"
# $4: if exist, read the file containing user defined parameters
if [ $# -lt 3 ]
then
  echo "********************************************************************"
  echo "* CAUTION!! DO NOT use the same subject name as the atlas template *"
  echo "*           if it is not for leave-one-out testing                 *"
  echo "********************************************************************"
  echo "usage: parcellation.sh new_image corresponding_mask atlas_folder"
  exit
fi

# setup default value for parameters
ROOT_DIR=$(pwd)
# export QSUB_CMD="qsub -l h_rt=5:00:00 -pe smp 4 -R y -l h_vmem=1G -l tmem=1G -j y -S /bin/sh -b y -cwd -V -o job_output -e job_error" # old flag: -l s_stack=128M
# export QSUB_CMD_ONE_CORE="qsub -l h_rt=5:00:00 -pe smp 1 -R y -l h_vmem=2G -l tmem=2G -j y -S /bin/sh -b y -cwd -V -o job_output -e job_error" # old flag: -l s_stack=128M
# export QSUB_SEG_MATH="qsub -l h_rt=1:00:00 -pe smp 4 -R y -l h_vmem=2G -l tmem=2G -j y -S /bin/sh -b y -cwd -V -o job_output -e job_error" # -l s_stack=128M

export QSUB_CMD="qsub -V -I -l walltime=5:00:00,pmem=1G -W group_list=ensc-image -o job_output -e job_error" # old flag: -l s_stack=128M
export QSUB_CMD_ONE_CORE="qsub -V -I -l walltime=5:00:00,pmem=1G -W group_list=ensc-image -o job_output -e job_error" # old flag: -l s_stack=128M
export QSUB_SEG_MATH="qsub -V -I -l walltime=5:00:00,pmem=1G -W group_list=ensc-image -o job_output -e job_error" # -l s_stack=128M

PARCELLATION_NNR="-ln 4 -lp 4 -sx -3"
DILATE=1 # value to be dilated for the result mask
LABFUSION="-STEPS"
LABFUSION_OPTION="-v 1" # parameter options for STAPLE or STEPS in seg_LabFusion
MASK_AFF=""

# Set STEPS parameters
if [[ -z $k ]] && [[ -z $n ]]; then  # if STEPS parameter is not set
  # set default STEPS parameter to: "3 8 "
  export k=3
  export n=8
fi
export STEPS_PARAMETER="${k} ${n} "

FULL_TEST_NAME=$(basename $1)
TEST_NAME=`echo "$FULL_TEST_NAME" | cut -d'.' -f1`
echo "Creating parcellation label for: "$TEST_NAME
export ATLAS=$(basename $3)
MASK=$2

# Read user-defined parameters
if [ ! -z $4 ]; then # check if there is a 4th argument
  if [ -f $4 ]; then # check if the file specified by 4th argument exist
    . $4 # if file of 4th argument exist, read the parameters from the file
  fi
fi

# create dilated mask for every template image if not already exist
if [ ! -d $3/mask ]; then
  echo "create mask for every template image if not done yet"
  mkdir $3/mask
fi
if [ ! -d $3/mask_dilate ]; then
  echo "create dilated mask for every template image if not done yet"
  mkdir $3/mask_dilate
fi
if [ ! -d job_output ]; then mkdir job_output; fi
if [ ! -d job_error ]; then mkdir job_error; fi
if [ ! -d temp/${ATLAS} ]; then mkdir -p temp/${ATLAS}; fi
if [ ! -d mask/${ATLAS} ]; then mkdir -p mask/${ATLAS}; fi
for G in `ls $3/template/`
do
  if [ ! -f $3/mask_dilate/$G ] && [ ! -f $3/mask_dilate/$G".nii" ] && [ ! -f $3/mask_dilate/$G".nii.gz" ] && [ ! -f $3/mask_dilate/$G".hdr" ]; then
    if [ ! -f $3/mask/$G ] && [ ! -f $3/mask/$G".nii" ] && [ ! -f $3/mask/$G".nii.gz" ] && [ ! -f $3/mask/$G".hdr" ]; then
      reg_tools -in $3/label/$G -bin -out $3/mask/$G
    fi
    seg_maths $3/mask/$G -dil ${DILATE} $3/mask_dilate/$G
  fi
done

if [ ! -d label ]; then mkdir label; fi
if [ ! -d label/${ATLAS} ]; then mkdir label/${ATLAS}; fi
if [ ! -d mask ]; then mkdir mask; fi

jmask="mask_${TEST_NAME}" # if no mask has been created yet, evoke mask.sh
if [ ! -f $2 ] && [ ! -f $2".nii" ] && [ ! -f $2".nii.gz" ] && [ ! -f $2".hdr" ]
then
  # create mask for the test image first
	if [ ! -z $4 ] && [ -f $4 ];  # check if there is a 4th argument# check if the file specified by 4th argument exist
	then . mask.sh $1 $3 $4 # if file of 4th argument exist, read the parameters from the file
	else . mask.sh $1 $3 # if there's no 4th argument or file not exist ("." eauqals to "source")
	fi # if path of the script is not defined in bashrc, use "./mask.sh" instead
  # Mask for the test image created
  MASK=mask/${TEST_NAME}_mask_${ATLAS}_STAPLE_d${DILATE}.nii.gz
  ${QSUB_CMD} -hold_jid ${jname_dilate} -N ${jmask} echo -e "Pre-defined mask ${MASK} NOT found, parcellation will start after the mask is generated"
else
  ${QSUB_CMD} -N ${jmask} echo -e "Pre-defined mask ${MASK} found, start to search/generate initial affine registration from atlas to test image now"
fi

# echo "*********************************************"
# echo "* Segmentation pipeline for mouse brain MRI *"
# echo "* for ${TEST_NAME} *"
# echo "*  using multi-atlas label fusion methods   *"
# echo "*     step 2 - structural parcellation      *"
# echo "*********************************************"
# echo "usage: parcellation new_image mask atlas_type (in_vivo/ex_vivo)"

# start structural parcellation
echo "Creating label for: "$TEST_NAME
PARAMETER_NUMBER=0
jid="$$" # generate a random number as job ID
jid_reg="reg_${jid}"
TEST_NAME=`echo "$(basename $1)" | cut -d'.' -f1`
for G in `ls $3/template/`
do
  NAME=`echo "$G" | cut -d'.' -f1`
  jname=${jid_reg}_${TEST_NAME}_${NAME}
  # Check testing image name is different from atlas template. If same, skip (for leave-one-out)
  if [[ ${3}/template/${NAME} != $1 ]] && [[ ${3}/template/${NAME}.nii != $1 ]] && [[ ${3}/template/${NAME}.nii.gz != $1 ]] && [[ ${3}/template/${NAME}.hdr != $1 ]]
  then
	  # 1) check if affine matrix exists
	  job_affine="${jname}_affine_matrix"
	  if [ ! -f temp/${ATLAS}/${NAME}_${TEST_NAME}_aff ]; then
		# 1.1） if affine matrix not found, generate affine atlas->test
		${QSUB_CMD} -hold_jid ${jmask} -N ${job_affine} reg_aladin -flo ${3}/template/${NAME} -ref $1 -fmask ${3}/mask_dilate/${NAME} -rmask ${MASK} -res temp/${ATLAS}/${NAME}_${TEST_NAME}_aff.nii.gz -aff temp/${ATLAS}/${NAME}_${TEST_NAME}_aff ${MASK_AFF} -omp 4  
	  else
		${QSUB_CMD} -hold_jid ${jmask} -N ${job_affine} echo -e "Pre-defined affine transformation matrix ${NAME}_${TEST_NAME}_aff found, begin non-rigid registration now"
	  fi
	  # 1.2) use affine transform matrix to initialize non-rigid registration (coarse step)
	  job_reg="${jname}_reg"
	  ${QSUB_CMD} -hold_jid ${job_affine} -N ${job_reg} reg_f3d -flo ${3}/template/${NAME} -fmask ${3}/mask_dilate/${NAME} -ref ${1} -rmask ${MASK} -aff temp/${ATLAS}/${NAME}_${TEST_NAME}_aff -res temp/${ATLAS}/${NAME}_${TEST_NAME}_f3d.nii.gz -cpp temp/${ATLAS}/${NAME}_${TEST_NAME}_cpp.nii.gz ${PARCELLATION_NNR} -omp 4
	  # 1.3) apply control point (coarse) to transform label/mask from atlas to test image
	  job_resample="${jname}_resample"
	  job_resample_nrr_mask=${job_resample}_nrr_mask
	  ${QSUB_CMD} -hold_jid ${job_reg} -N ${job_resample_nrr_mask} reg_resample -flo ${3}/mask/${NAME} -ref ${1} -cpp temp/${ATLAS}/${NAME}_${TEST_NAME}_cpp.nii.gz -NN -res mask/${ATLAS}/${TEST_NAME}_nrr_mask_${NAME}.nii.gz
	  job_resample_label=${job_resample}_label
	  ${QSUB_CMD} -hold_jid ${job_reg} -N ${job_resample_label} reg_resample -flo ${3}/label/${NAME} -ref ${1} -cpp temp/${ATLAS}/${NAME}_${TEST_NAME}_cpp.nii.gz -NN -res label/${ATLAS}/${TEST_NAME}_label_${NAME}.nii.gz
	
	# 2) prepare parameters for label fusion
    if (( $PARAMETER_NUMBER==0 )); then
      FIRST_TEMPLATE="temp/${ATLAS}/${NAME}_${TEST_NAME}_f3d.nii.gz"
 	  FIRST_MASK="mask/${ATLAS}/${TEST_NAME}_nrr_mask_${NAME}.nii.gz"
	  FIRST_LABEL="label/${ATLAS}/${TEST_NAME}_label_${NAME}.nii.gz"
    else
      MERGE_TEMPLATE="${MERGE_TEMPLATE} temp/${ATLAS}/${NAME}_${TEST_NAME}_f3d.nii.gz"
	  MERGE_MASK="${MERGE_MASK} mask/${ATLAS}/${TEST_NAME}_nrr_mask_${NAME}.nii.gz"
	  MERGE_LABEL="${MERGE_LABEL} label/${ATLAS}/${TEST_NAME}_label_${NAME}.nii.gz"
    fi
    let PARAMETER_NUMBER+=1
  else
	echo -e "Atlas image name ${TEST_NAME} is same as test image, skipped"
  fi
done
let PARAMETER_NUMBER-=1

# Prepare 4D images for label fusion
jid_4d="merge4d_${TEST_NAME}"
# create average rough mask to reduce memory usage for label fusion
jid_4d_nrr_mask_avg="${jid_4d}_nrr_mask_avg"
${QSUB_CMD} -hold_jid ${jid_reg}_* -N ${jid_4d_nrr_mask_avg} reg_average mask/${ATLAS}/${TEST_NAME}_nrr_mask_avg.nii.gz -avg $FIRST_MASK $MERGE_MASK
jid_4d_nrr_mask_avg_bin="${jid_4d}_nrr_mask_avg_bin"
${QSUB_CMD} -hold_jid ${jid_4d_nrr_mask_avg} -N ${jid_4d_nrr_mask_avg_bin} seg_maths mask/${ATLAS}/${TEST_NAME}_nrr_mask_avg.nii.gz -bin mask/${ATLAS}/${TEST_NAME}_mask_avg_bin.nii.gz
jid_4d_nrr_mask="${jid_4d}_nrr_mask"
${QSUB_SEG_MATH} -hold_jid ${jid_reg}_* -N ${jid_4d_nrr_mask} seg_maths $FIRST_MASK -merge $PARAMETER_NUMBER 4 $MERGE_MASK mask/${ATLAS}/${TEST_NAME}_nrr_mask_4D.nii.gz
jid_4d_label="${jid_4d}_label"
${QSUB_SEG_MATH} -hold_jid ${jid_reg}_* -N ${jid_4d_label} seg_maths $FIRST_LABEL -merge $PARAMETER_NUMBER 4 $MERGE_LABEL label/${ATLAS}/${TEST_NAME}_label_4D.nii.gz
# Start label fusion
export jid_LabFusion="LabFusion_${TEST_NAME}"
# Determine which label fusion method to use
if [[ ${LABFUSION}=="-STEPS" ]]; then
  jid_4d_tempate="${jid_4d}_template"
  ${QSUB_SEG_MATH} -hold_jid ${jid_reg}_* -N ${jid_4d_tempate} seg_maths $FIRST_TEMPLATE -merge $PARAMETER_NUMBER 4 $MERGE_TEMPLATE label/${ATLAS}/${TEST_NAME}_template_4D.nii.gz
  ${QSUB_SEG_MATH} -hold_jid ${jid_4d}_* -N ${jid_LabFusion} seg_LabFusion \
  -in label/${ATLAS}/${TEST_NAME}_label_4D.nii.gz \
  -STEPS ${k} ${n} $1 label/${ATLAS}/${TEST_NAME}_template_4D.nii.gz ${LABFUSION_OPTION} \
  -mask mask/${ATLAS}/${TEST_NAME}_mask_avg_bin.nii.gz \
  -out label/${TEST_NAME}_label_${ATLAS}_STEPS_${k}_${n}.nii.gz
  
  # Creating NRR mask
  jid_NRR_mask="NRR_mask_${TEST_NAME}"
  ${QSUB_CMD} -hold_jid ${jid_4d}_* -N ${jid_NRR_mask} seg_LabFusion \
  -in mask/${ATLAS}/${TEST_NAME}_nrr_mask_4D.nii.gz \
  -STEPS ${k} ${n} $1 label/${ATLAS}/${TEST_NAME}_template_4D.nii.gz ${LABFUSION_OPTION} \
  -mask mask/${ATLAS}/${TEST_NAME}_mask_avg_bin.nii.gz \
  -out mask/${TEST_NAME}_mask_${ATLAS}_NRR_STEPS_${k}_${n}.nii.gz
  jid_NRR_mask_dilate="dil_NRR_mask_${TEST_NAME}"
  ${QSUB_CMD} -hold_jid ${jid_NRR_mask} -N ${jid_NRR_mask_dilate} seg_maths mask/${TEST_NAME}_mask_${ATLAS}_NRR_STEPS_${k}_${n}.nii.gz -dil ${DILATE} mask/${TEST_NAME}_mask_${ATLAS}_NRR_STEPS_${k}_${n}_d${DILATE}.nii.gz
fi












