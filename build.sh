#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

usage()
{
    echo "Build .NET Core product"
    echo "build.sh [options]"
    echo ""
    echo "Options"
    echo " -s|--netcore_sdk_path [.NET Core SDK Path]"
    echo " -f|--shared_framework_path [Shared Framework Path]"
    echo " -h|--help"
}

CLIPAYLOAD=""
SHAREDFRAMEWORKPATH=""
SDKVERSION=""
ADDITIONALARGS=()

while [[ $# -gt 0 ]]
  do
    key="$1"

    case $key in
      -s|--netcore_sdk_path)
      CLIPAYLOAD="$2"
      shift 2
      ;;
      -f|--shared_framework_path)
      SHAREDFRAMEWORKPATH="$2"
      shift 2
      ;;
      -h|--help)
      usage
      exit 0
      ;;
      *)
      ADDITIONALARGS+=($key)
      shift
    esac
done

SCRIPT_ROOT="$(cd -P "$( dirname "$0" )" && pwd)"
CLIPATH="$SCRIPT_ROOT/Tools/dotnetcli"

if [[ ! "$CLIPAYLOAD" == "" ]] && [[ ! -d "$CLIPAYLOAD" ]]; then
  echo "--clipayload option specified, but cannot find directory '$CLIPAYLOAD'"
  exit 1
fi
if [[ ! "$SHAREDFRAMEWORKPATH" == "" ]] && [[ ! -d "$SHAREDFRAMEWORKPATH" ]]; then
  echo "--shared_framework_path option specified, but cannot find directory '$SHAREDFRAMEWORKPATH'"
  exit 1
fi

if [[ ! "$CLIPAYLOAD" == "" ]] && [[ "$SHAREDFRAMEWORKPATH" == "" ]]; then
  echo "Missing required parameter '--shared_framework_path'"
  exit 1
fi

if [[ ! "$CLIPAYLOAD" == "" ]]; then
  echo "Using specified payload from $CLIPAYLOAD"
  CLIPATH="$CLIPAYLOAD"

  # Determine SDK Version from cli payload
  declare -a SDKVERSIONS=()
  SDKVERSIONS=($(ls $CLIPAYLOAD/sdk))
  if [[ "${#SDKVERSIONS[@]}" -gt "1" ]]; then
    echo "Discovered SDK versions:"
    echo "  ${SDKVERSIONS[*]}"
    echo "Multiple sdk versions found.  Only one sdk version is permitted, please remove extra sdks."
    exit 1
  fi
  if [[ "${#SDKVERSIONS[@]}" == "0" ]]; then
    echo "Unable to determine sdk version.  Did you download and extract a '.NET CORE SDK' from https://github.com/dotnet/cli?"
    exit 1
  fi
  SDKVERSION="${SDKVERSIONS[0]}"
fi

export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1

# bootstrap the CLI if no local payload is specified
if [[ "$CLIPAYLOAD" == "" ]]; then
  SDKVERSION="$(cat $SCRIPT_ROOT/.cliversion)"
  ./bootstrap/bootstrap.sh
fi

if [[ ! "$CLIPAYLOAD" == "" ]]; then
  ./bootstrap/bootstrap-unsupported.sh -s $CLIPAYLOAD -f $SHAREDFRAMEWORKPATH -o $CLIPAYLOAD.patch
  CLIPATH=$CLIPAYLOAD.patch
fi

SDKPATH="$CLIPATH/sdk/$SDKVERSION"
echo "SDKPATH: $SDKPATH"

if [[ ! -d $SDKPATH ]]; then
  echo "Error: Unable to find CLI sdk at '$SDKPATH'."
  exit 1
fi


$CLIPATH/dotnet restore tasks/Microsoft.DotNet.SourceBuild.Tasks/Microsoft.DotNet.SourceBuild.Tasks.csproj
$CLIPATH/dotnet build tasks/Microsoft.DotNet.SourceBuild.Tasks/Microsoft.DotNet.SourceBuild.Tasks.csproj
echo "$CLIPATH/dotnet $SDKPATH/MSBuild.dll $SCRIPT_ROOT/build.proj ${ADDITIONALARGS[@]}"
$CLIPATH/dotnet $SDKPATH/MSBuild.dll $SCRIPT_ROOT/build.proj "${ADDITIONALARGS[@]}"

if [[ ! "$CLIPAYLOAD" == "" ]]; then
  echo "Patch CLI with built binaries"
#  $SCRIPT_ROOT/buildscripts/patchpayload.sh --verbose --netcore_sdk_path "$CLIPAYLOAD" --coreclr_repo_path $SCRIPT_ROOT/src/coreclr --corefx_repo_path $SCRIPT_ROOT/src/corefx --coresetup_repo_path $SCRIPT_ROOT/src/core-setup
fi
exit 0
