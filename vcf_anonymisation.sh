#!/bin/bash

# All SNV and SV VCFs to be processed should be in the cwd
# Also requires a .tsv map file where each line has the format:
# <study ID>\t<germline sample LP number>\t<tumour sample LP number>


# define map file, VCF file patterns, and study ID pattern
map_file="id_map.tsv"
file_patterns=("*.somatic.vcf*" "*.SV.*")
study_id_pattern="\./[a-zA-Z]{3}_[0-9]{4}_[a-zA-Z]{3}"

for pattern in "${file_patterns[@]}"; do

    echo "Processing files with pattern: ${pattern}"

    # find all files with current pattern
    echo "Identifying input VCFs"
    vcfs=$(find . -iname "$pattern")

    # define the output file format
    if [[ "$pattern" == "*.somatic.vcf*" ]]; then
        renamed_suffix=".somatic.vcf"
        regex_suffix="\.somatic\.vcf\.gz"
        files_to_merge="normalised_files_snv.txt"
        merged_output="multi_sample.somatic.vcf.gz"
    elif [[ "$pattern" == "*.SV.*" ]]; then
        renamed_suffix=".somatic.merged.SV.CNV.vcf"
        regex_suffix="\.somatic\.merged\.SV\.CNV\.vcf\.gz"
        files_to_merge="normalised_files_sv.txt"
        merged_output="multi_sample.somatic.merged.SV.CNV.vcf.gz"
    fi

    # iterate over lines of map file
    echo "Renaming VCFs"

    while read -r study_id germline tumour; do

        # define replacement values for current germline/tumour ids
        germline_fixed=${study_id}"_germline"
        tumour_fixed=${study_id}"_tumour"

        # find VCF with current germline tumour id
        for vcf in $vcfs; do
            if [[ $vcf == *"$germline"* ]]; then

                # define output filenames
                new_vcf="${study_id}${renamed_suffix}"
                new_gz=${new_vcf}".gz"

                # get file contents, replace LP numbers, save as new filename
                zcat "$vcf" | sed -e s/"${germline}"/"${germline_fixed}"/g -e s/"${tumour}"/"${tumour_fixed}"/g > "$new_vcf"
                gzip "$new_vcf"

                # upload to DNAnexus
                # dx upload --brief "$new_gz"
            fi
        done
    done < "$map_file"

    # normalise files before merging
    echo "Identifying files to merge"
    gz_files=$(find . -regextype posix-extended -iregex "${study_id_pattern}${regex_suffix}")

    echo "Normalising files"

    for gz_file in $gz_files; do

        # define name for normalised VCF
        gz_file=${gz_file##*"/"}
        vcf_file=${gz_file%".gz"}
        new_gz="normalised_${vcf_file}.gz"

        # bcftools needs files in bgzip, not gzip
        if [[ -e "$gz_file" ]]; then
            gunzip "$gz_file"
        fi

        bgzip "$vcf_file"

        # left-align indels & decompose multiallelics; create file index
        bcftools norm -m - -o "$new_gz" "$gz_file"
        bcftools index -f "$new_gz"

        # add normalised file to list of files to merge
        printf "%s\n" "$new_gz" >> "$files_to_merge"

    done

    # merge files
    echo "Merging files"
    bcftools merge -l "$files_to_merge" -o "$merged_output"

done
