# vcf_anonymisation

Purpose:

Given a set of single-nucleotide variant (SNV) and structural variant (SV) VCFs from patient cases with paired germline and tumour samples...

	1. Rename each VCF so that "<LP number 1>_<LP number 2>.vcf.gz" becomes "<study ID>.vcf.gz"
	2. Within each VCF, replace any instances of the germline and tumour sample LP numbers with "<study ID>_germline" and "<study ID>_tumour" respectively
	3. Create a multi-sample SNV VCF and a multi-sample SV VCF


## Step 0

Do some sanity checking on filenames and compression before anything else, make sure all the VCFs have standardised file extensions and are gzipped.

Various issues I encountered with this included (but are probably not limited to):

- VCF has .gz extension but isn't gzipped
- VCF is gzipped but doesn't have .gz extension
- VCF has evidently been duplicated at some point because filename ends with " (1).vcf..."
- SV VCFs with different filename suffixes e.g. ".SV.CNV.vcf" and ".SV.vcf"


## Step 1

Get a mapping between patient IDs and sample LP numbers; and identify which sample LP number is germline/tumour.

- The supplementary.html file for a patient's case has details on the patient ID and sample LP numbers, including which sample is germline and which is tumour. However, it also contains a lot of patient identifiable information, so can't be uploaded to the internet.
- In any case, you want to end up with a TSV file with 3 columns: patient ID, LP germline sample number, and LP tumour sample number; with one patient per line.


## Step 2

Combine this with the mapping between patient IDs and study IDs.

The .tsv map file still needs the study IDs associated with each patient ID, so you need a decode file which provides you with that mapping.

- Open both the TSV file you just created and the decode file with excel
- Sort both files by the patient ID column
- Copy the patient ID and study ID columns from the decode file into the TSV file
- In the same file, match study IDs to sample LP numbers via shared patient ID values
- You want to end up with 4 columns in the TSV file: study ID, patient ID, LP germline sample number, and LP tumour sample number
- Then delete the patient ID column
- Save the updated TSV file.


## Step 3

Process all cases by executing vcf_anonymisation.sh.

This script assumes that the .tsv map file and all VCFs are in the cwd. Since this is a large amount of data, you might want to use a cloud workstation.
It renames all VCFs, replaces all instances of LP numbers, and creates merged multisample VCFs.
Renamed VCFs are uploaded back to the DNAnexus cwd, so you may also want to create separate folders to hold the original and renamed files.

Processing using a cloud workstation:

```
# log into dnanexus, select the project, upload the files you need, and start a cloud workstation
dx login
dx select <project>
dx upload <map file>.tsv
dx upload vcf_anonymisation.sh
dx run --ssh app-cloud_workstation

# once the workstation has started, get the project context
unset DX_WORKSPACE_ID
dx cd $DX_PROJECT_CONTEXT_ID:

# download the files
dx download vcf_anonymisation.sh -f
dx download <map file>.tsv -f
dx download *.vcf* -f

# run the script
bash vcf_anonymisation.sh
```

Don't forget to upload the output afterwards.
