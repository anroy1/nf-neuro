
process REGISTRATION_ANTS {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://scil.usherbrooke.ca/containers/scilus_2.0.2.sif':
        'scilus/scilus:2.0.2' }"

    input:
    tuple val(meta), path(fixedimage), path(movingimage), path(mask) //** optional, input = [] **//

    output:
    tuple val(meta), path("*_warped.nii.gz")                        , emit: image
    tuple val(meta), path("*__output0Warp.nii.gz")                  , emit: warp, optional:true
    tuple val(meta), path("*__output1GenericAffine.mat")            , emit: affine
    tuple val(meta), path("*__output1InverseWarp.nii.gz")           , emit: inverse_warp, optional: true
    tuple val(meta), path("*__output0InverseAffine.mat")            , emit: inverse_affine
    path "versions.yml"                                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def ants = task.ext.quick ? "antsRegistrationSyNQuick.sh " :  "antsRegistrationSyN.sh "
    def dimension = task.ext.dimension ? "-d " + task.ext.dimension : "-d 3"
    def transform = task.ext.transform ? task.ext.transform : "s"
    def seed = task.ext.random_seed ? " -e " + task.ext.random_seed : "-e 1234"

    if ( task.ext.threads ) args += "-n " + task.ext.threads
    if ( task.ext.initial_transform ) args += " -i " + task.ext.initial_transform
    if ( task.ext.histogram_bins ) args += " -r " + task.ext.histogram_bins
    if ( task.ext.spline_distance ) args += " -s " + task.ext.spline_distance
    if ( task.ext.gradient_step ) args += " -g " + task.ext.gradient_step
    if ( task.ext.mask ) args += " -x $mask"
    if ( task.ext.type ) args += " -p " + task.ext.type
    if ( task.ext.histogram_matching ) args += " -j " + task.ext.histogram_matching
    if ( task.ext.repro_mode ) args += " -y " + task.ext.repro_mode
    if ( task.ext.collapse_output ) args += " -z " + task.ext.collapse_output

    """
    export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=$task.cpus
    export OMP_NUM_THREADS=1
    export OPENBLAS_NUM_THREADS=1

    $ants $dimension -f $fixedimage -m $movingimage -o output -t $transform $args $seed

    mv outputWarped.nii.gz ${prefix}__warped.nii.gz
    mv output0GenericAffine.mat ${prefix}__output1GenericAffine.mat

    if [ $transform != "t" ] && [ $transform != "r" ] && [ $transform != "a" ];
    then
        mv output1InverseWarp.nii.gz ${prefix}__output1InverseWarp.nii.gz
        mv output1Warp.nii.gz ${prefix}__output0Warp.nii.gz
    fi

    antsApplyTransforms -d 3 -i $fixedimage -r $movingimage -o Linear[output.mat]\
                        -t [${prefix}__output1GenericAffine.mat,1]

    mv output.mat ${prefix}__output0InverseAffine.mat


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ants: \$(antsRegistration --version | grep "Version" | sed -E 's/.*v([0-9]+\\.[0-9]+\\.[0-9]+).*/\\1/')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    touch ${prefix}__t1_warped.nii.gz
    touch ${prefix}__output1GenericAffine.mat
    touch ${prefix}__output0InverseAffine.mat
    touch ${prefix}__output1InverseWarp.nii.gz
    touch ${prefix}__output0Warp.nii.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ants: \$(antsRegistration --version | grep "Version" | sed -E 's/.*v([0-9]+\\.[0-9]+\\.[0-9]+).*/\\1/')
    END_VERSIONS

    function handle_code () {
    local code=\$?
    ignore=( 1 )
    exit \$([[ " \${ignore[@]} " =~ " \$code " ]] && echo 0 || echo \$code)
    }
    trap 'handle_code' ERR

    antsRegistrationSyNQuick.sh -h
    antsApplyTransforms -h
    """
}
