#!/bin/bash

#===============================================================================
# METAGENOMIC PROFILING PIPELINE - SETUP SCRIPT
#===============================================================================
# This script downloads and sets up all required databases and containers
# for the metagenomic profiling pipeline.
#
# Usage:
#   ./setup_pipeline.sh [INSTALLATION_DIRECTORY]
#
# Example:
#   ./setup_pipeline.sh /shared/pipeline_resources
#   ./setup_pipeline.sh  (interactive mode - will prompt for directory)
#
# Author: LPM
# Version: 1.0.0
#===============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script start time
START_TIME=$(date +%s)

#===============================================================================
# FUNCTIONS
#===============================================================================

print_header() {
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${BLUE}  METAGENOMIC PROFILING PIPELINE - SETUP${NC}"
    echo -e "${BLUE}======================================================================${NC}"
    echo ""
}

log_info() {
    if [ -n "${LOGFILE:-}" ]; then
        echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOGFILE}"
    else
        echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    fi
}

log_warn() {
    if [ -n "${LOGFILE:-}" ]; then
        echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOGFILE}"
    else
        echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    fi
}

log_error() {
    if [ -n "${LOGFILE:-}" ]; then
        echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOGFILE}"
    else
        echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    fi
}

log_success() {
    if [ -n "${LOGFILE:-}" ]; then
        echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOGFILE}"
    else
        echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    fi
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 is not installed or not in PATH"
        exit 1
    fi
}

#===============================================================================
# GET INSTALLATION DIRECTORY
#===============================================================================

print_header

if [ $# -eq 0 ]; then
    # Interactive mode
    echo -e "${YELLOW}No installation directory provided.${NC}"
    echo ""
    echo "Please enter the full path where you want to install pipeline resources:"
    echo "(This will create subdirectories: databases/ and singularity_cache/)"
    echo ""
    read -p "Installation directory: " INSTALL_DIR
    
    # Trim whitespace
    INSTALL_DIR=$(echo "$INSTALL_DIR" | xargs)
    
    if [ -z "$INSTALL_DIR" ]; then
        log_error "No directory provided. Exiting."
        exit 1
    fi
else
    # Command line argument
    INSTALL_DIR="$1"
fi

# Convert to absolute path
INSTALL_DIR=$(realpath -m "$INSTALL_DIR")

log_info "Installation directory: ${INSTALL_DIR}"
echo ""

# Confirm with user
read -p "Continue with this directory? (yes/no): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy][Ee][Ss]$|^[Yy]$ ]]; then
    log_warn "Installation cancelled by user."
    exit 0
fi

#===============================================================================
# SETUP DIRECTORIES
#===============================================================================

echo ""
log_info "Setting up directory structure..."

# Check current directory
PIPELINE_DIR=$(pwd)
PIPELINE_DIR=$(realpath -m "$PIPELINE_DIR")
echo ${PIPELINE_DIR}

# Create main directory
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# Create subdirectories
mkdir -p singularity_cache
mkdir -p logs
mkdir -p bowtie_phix
mkdir -p hostile_index

# Setup log file
LOGFILE="${INSTALL_DIR}/logs/setup_$(date +%Y%m%d_%H%M%S).log"
touch "${LOGFILE}"

log_success "Directory structure created:"
log_info "  - ${INSTALL_DIR}/singularity_cache"
log_info "  - ${INSTALL_DIR}/logs"
log_info "  - ${INSTALL_DIR}/bowtie_phix"
log_info "  - ${INSTALL_DIR}/hostile_index"

log_info "Log file: ${LOGFILE}"

#===============================================================================
# CHECK REQUIRED TOOLS
#===============================================================================

echo ""
log_info "Checking required tools..."

check_command wget
check_command tar
check_command singularity

log_success "All required tools are available"

#===============================================================================
# DOWNLOAD SINGULARITY CONTAINERS
#===============================================================================

echo ""
log_info "========================================="
log_info "STEP 1/5: Downloading Singularity containers"
log_info "========================================="

SING_DIR="${INSTALL_DIR}/singularity_cache"
cd "${SING_DIR}"

declare -A CONTAINERS=(

    ["quay.io-biocontainers-fastqc-0.12.1--hdfd78af_0.img"]="docker://quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0"
    ["quay.io-biocontainers-multiqc-1.21--pyhdfd78af_0.img"]="docker://quay.io/biocontainers/multiqc:1.21--pyhdfd78af_0"
    ["quay.io-biocontainers-pandas-2.2.1.img"]="docker://quay.io/biocontainers/pandas:2.2.1"
    ["quay.io-biocontainers-seaborn-0.13.2.img"]="docker://quay.io/biocontainers/seaborn:0.13.2"
    ["quay.io-biocontainers-metaphlan-4.2.4--pyhdfd78af_0.img"]="docker://quay.io/biocontainers/metaphlan:4.2.4--pyhdfd78af_0"
    ["quay.io-biocontainers-fastp-0.23.4--hadf994f_3.img"]="docker://quay.io/biocontainers/fastp:0.23.4--hadf994f_3"
    ["quay.io-biocontainers-bowtie2-2.5.5--ha27dd3b_0.img"]="docker://quay.io/biocontainers/bowtie2:2.5.5--ha27dd3b_0"
                                                                                                    
)
CONTAINER_COUNT=0
TOTAL_CONTAINERS=${#CONTAINERS[@]}

for img_name in "${!CONTAINERS[@]}"; do
    CONTAINER_COUNT=$((CONTAINER_COUNT + 1))
    
    if [ -f "${img_name}" ]; then
        log_warn "[${CONTAINER_COUNT}/${TOTAL_CONTAINERS}] ${img_name} already exists. Skipping."
    else
        log_info "[${CONTAINER_COUNT}/${TOTAL_CONTAINERS}] Pulling ${img_name}..."
        
        uri="${CONTAINERS[$img_name]}"
        
        singularity pull --name "${img_name}" "${uri}" >> "${LOGFILE}" 2>&1
        
        if [ $? -eq 0 ]; then
            log_success "[${CONTAINER_COUNT}/${TOTAL_CONTAINERS}] ${img_name} downloaded successfully"
        else
            log_error "[${CONTAINER_COUNT}/${TOTAL_CONTAINERS}] Failed to download ${img_name}"
            exit 1
        fi
    fi
done


#===============================================================================
# BUILDING BOWTIE INDEXES
#===============================================================================

echo ""
log_info "========================================="
log_info "STEP 2/5: Building bowtie indexes"
log_info "========================================="

BOWTIE_DIR="${INSTALL_DIR}/bowtie_phix"
cd "${BOWTIE_DIR}"

if [ -f "phiX174.1.bt2" ]; then
    log_warn "Bowtie indexes already present. Skipping."
else
    log_info "Downloading the phiX174 genome."
    singularity exec ${SING_DIR}/quay.io-biocontainers-entrez-direct-24.0--he881be0_0.img efetch -db nucleotide -id NC_001422.1 -format fasta > phiX174.fasta
    
    if [ $? -eq 0 ]; then
        log_success "Download completed"
        
        log_info "Building bowtie indexes for phiX174 genome..."

        singularity exec \
        --bind ${INSTALL_DIR}:/${INSTALL_DIR} \
        ${SING_DIR}/quay.io-biocontainers-bowtie2-2.5.5--ha27dd3b_0.img \
        bowtie2-build phiX174.fasta phiX174

        if [ -f "phiX174.1.bt2" ]; then
            log_success "Indexes built succesfully"
        
        else
            log_error "Process failed"
            exit 1
        fi
    else
        log_error "Process failed"
        exit 1
    fi
fi

#===============================================================================
# DOWNLOAD HUMAN DECONTAMINATION INDEX
#===============================================================================

echo ""
log_info "========================================="
log_info "STEP 3/5: Downloading human decontamination bowtie2 index"
log_info "========================================="

HOSTILE_DIR="${INSTALL_DIR}/hostile_index"
cd "${HOSTILE_DIR}"

if ls human-t2t-hla-argos985-mycob140*.bt2 1>/dev/null 2>&1; then
    log_warn "Human decontamination index already present. Skipping."
else
    log_info "Downloading human-t2t-hla-argos985-mycob140 bowtie2 index..."

    wget "https://objectstorage.uk-london-1.oraclecloud.com/n/lrbvkel2wjot/b/human-genome-bucket/o/human-t2t-hla-argos985-mycob140.tar" \
        -O human-t2t-hla-argos985-mycob140.tar 2>&1 | tee -a "${LOGFILE}"

    if [ $? -eq 0 ]; then
        log_info "Extracting bowtie2 index..."
        tar -xf human-t2t-hla-argos985-mycob140.tar >> "${LOGFILE}" 2>&1
        rm human-t2t-hla-argos985-mycob140.tar

        if ls human-t2t-hla-argos985-mycob140*.bt2 1>/dev/null 2>&1; then
            log_success "Human decontamination index downloaded successfully"
        else
            log_error "Index extraction failed"
            exit 1
        fi
    else
        log_error "Failed to download human decontamination index"
        exit 1
    fi
fi

#===============================================================================
# DOWNLOAD MetaPhlAn4 DATABASE
#===============================================================================

echo ""
log_info "========================================="
log_info "STEP 4/5: Downloading MetaPhlAn4 database"
log_info "========================================="

METAPHLAN_DB_DIR="${INSTALL_DIR}/databases/metaphlan4"
METAPHLAN_IMG="${SING_DIR}/quay.io-biocontainers-metaphlan-4.2.4--pyhdfd78af_0.img"

if [ -d "${METAPHLAN_DB_DIR}/metaphlan_db" ] && [ "$(ls -A ${METAPHLAN_DB_DIR}/metaphlan_db)" ]; then
    log_warn "MetaPhlAn4 database already exists. Skipping download."
else
    log_info "Installing MetaPhlAn4 database..."
    log_info "This may take 10-20 minutes (database is ~20GB)..."
    
    mkdir -p "${METAPHLAN_DB_DIR}/metaphlan_db"
    
    singularity exec "${METAPHLAN_IMG}" metaphlan \
        --install \
        --index latest \
        --db_dir "${METAPHLAN_DB_DIR}/metaphlan_db" \
        --nproc 4 >> "${LOGFILE}" 2>&1
    
    if [ $? -eq 0 ]; then
        log_success "MetaPhlAn4 database installed successfully"
    else
        log_error "Failed to install MetaPhlAn4 database"
        exit 1
    fi
fi

#===============================================================================
# DOWNLOAD KRAKEN2 DATABASE
#===============================================================================

echo ""
log_info "========================================="
log_info "STEP 5/5: Downloading KRAKEN2 database"
log_info "========================================="

KRAKEN_DB_DIR="${INSTALL_DIR}/databases/kraken_db"

if [ -d "${KRAKEN_DB_DIR}/kraken_db" ] && [ "$(ls -A ${KRAKEN_DB_DIR}/kraken_db)" ]; then
    log_warn "Kraken2 database already exists. Skipping download."
else
    log_info "Downloading KRAKEN2 database..."
    log_info "This may take couple of minutes (database is ~8GB)..."
    
    mkdir -p "${KRAKEN_DB_DIR}/kraken_db"
    cd "${KRAKEN_DB_DIR}/kraken_db"

    wget "https://genome-idx.s3.amazonaws.com/kraken/k2_pluspf_08_GB_20260226.tar.gz"
    tar -xvzf k2_pluspf_08_GB_20260226.tar.gz
    rm k2_pluspf_08_GB_20260226.tar.gz

    if [ $? -eq 0 ]; then
        log_success "Kraken2 database downloaded successfully"
    else
        log_error "Failed to download Kraken2 database"
        exit 1
    fi
fi

#===============================================================================
# GENERATE CONFIGURATION FILE
#===============================================================================

echo ""
log_info "========================================="
log_info "Generating pipeline configuration"
log_info "========================================="

CONFIG_FILE="${INSTALL_DIR}/pipeline_paths.config"

cat > "${CONFIG_FILE}" << EOF
/*
========================================================================================
    Pipeline Resource Paths Configuration
========================================================================================
    Generated by setup_pipeline.sh on $(date)
    
    Use this configuration with:
    nextflow run main.nf -c ${CONFIG_FILE} [other options]
========================================================================================
*/

params {
    // Cache directories
    singularity_cache_dir = '${INSTALL_DIR}/singularity_cache'
    classifiers_dir    = '${INSTALL_DIR}/classifiers'
    bowtie_dir         = '${INSTALL_DIR}/bowtie_phix'
    hostile_index_dir  = '${INSTALL_DIR}/hostile_index'
    blast_db_dir       = '${INSTALL_DIR}/blast_db'
}
EOF

log_success "Configuration file created: ${CONFIG_FILE}"

#===============================================================================
# SUMMARY
#===============================================================================

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}  SETUP COMPLETE!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo ""
log_success "All resources downloaded and installed successfully"
echo ""
echo "Installation Summary:"
echo "  - Installation directory: ${INSTALL_DIR}"
echo "  - Total time: ${MINUTES} minutes ${SECONDS} seconds"
echo ""
echo "Resource Locations:"
echo "  - Classifiers:     ${INSTALL_DIR}/classifiers/"
echo "  - Hostile index:      ${INSTALL_DIR}/hostile_index/"
echo "  - Bowtie PhiX:       ${INSTALL_DIR}/bowtie_phix/"
echo "  - Containers:         ${INSTALL_DIR}/singularity_cache/"
echo "  - Configuration:      ${CONFIG_FILE}"
echo "  - Log file:           ${LOGFILE}"
echo ""
echo "Next Steps:"
echo "  1. Run the pipeline with:"
echo "     nextflow run main.nf -c ${CONFIG_FILE} --input samples.csv --outdir results"
echo ""
echo "  2. Or manually specify paths:"
echo "     nextflow run main.nf \\"
echo "       --singularity_cache_dir ${INSTALL_DIR}/singularity_cache \\"
echo "       --classifiers ${INSTALL_DIR}/classifiers \\"
echo "       --input samples.csv --outdir results"
echo ""
echo -e "${GREEN}======================================================================${NC}"