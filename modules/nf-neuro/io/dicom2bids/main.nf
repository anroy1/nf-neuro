process IO_DICOM2BIDS {
    tag "$meta.id"
    label 'process_single'

    container "unfmontreal/dcm2bids:3.2.0"

    input:
    tuple val(meta), path(dicom_dir)

    output:
    tuple val(meta), path("${bids_dir}/**"), emit: bids
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    dcm2bids_scaffold -o /bids_dir

    dcm2bids_helper -o /bids -d $dicom_dir

    dcm2bids --auto_extract_entities --bids_validate -o /bids -d $dicoms_dir -c /config.json -p 001

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dcm2bids: \$(dcm2bids --version |& sed '1!d ; s/dcm2bids //')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${bids_dir}/dataset_description.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dcm2bids: stub
    END_VERSIONS
    """
}
