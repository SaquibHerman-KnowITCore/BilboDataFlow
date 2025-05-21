# set the subscription
set -e

export ARM_SUBSCRIPTION_ID="e1b4bba1-73df-4932-96ca-85ee85fec54a"

# set the application / environment
export TF_VAR_application_name="bilbodataflow"
export TF_VAR_environment_name="dev"

# set the backend
export BACKEND_RESOURCE_GROUP="rg-bilbodataflow-dev"
export BACKEND_STORAGE_ACCOUNT="stbilbodataflowdev"
export BACKEND_STORAGE_CONTAINER="tfstate"
export BACKEND_KEY=$TF_VAR_application_name-$TF_VAR_environment_name

# ⬇ change directory to dev environment
cd "$(dirname "$0")/../environments/dev"

# run terraform
terraform init \
    -backend-config="resource_group_name=${BACKEND_RESOURCE_GROUP}" \
    -backend-config="storage_account_name=${BACKEND_STORAGE_ACCOUNT}" \
    -backend-config="container_name=${BACKEND_STORAGE_CONTAINER}" \
    -backend-config="key=${BACKEND_KEY}" \
    -reconfigure

terraform $*

# clean up the local environment
rm -rf .terraform