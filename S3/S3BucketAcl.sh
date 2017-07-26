#!/bin/sh
# To run this script, you will need to have valid access id and token
# saved in the ~/.AWS/credentials file.
# For JSON parsing, you should have installed jq. Use Homebrew or any other
# standard installer to install jq. You should also have awscli installed.
# Use pip or other installer tools to install AWSCLI.
# This script is supposed to run under an authorized user.

export bucketsResponse=`aws s3api list-buckets --profile saml`
export bucketNames=`echo $bucketsResponse | jq '.Buckets[] .Name ' | sed 's/"//g'`
export publicURI=http://acs.amazonaws.com/groups/global/AllUsers
export flaggedPermissions=("READ" "WRITE" "READ_ACP" "WRITE_ACP" "FULL_CONTROL")

containsElement () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 1; done
  return 0
}

for bucketName in $bucketNames; 
do 
	#GNU (Windows): sed ':a;N;$!ba;s/\n/ /g'
	#BSD (Mac): sed -e ':a' -e 'N' -e '$!ba' -e 's/\\n/ /g' |
	buckets=`aws s3api get-bucket-acl --bucket $bucketName --profile saml | sed 's/ //g'`
	bucketOwner=`echo $buckets | jq '.Owner.DisplayName' | sed 's/"//g'`
	bucketAcls=`echo $buckets | jq '.Grants[]' | sed 's/ //g' | sed -e ':a' -e 'N' -e '$!ba' -e 's/}\\n{/}   {/g' | sed -e ':a' -e 'N' -e '$!ba' -e 's/\\n//g'`
	length=`echo $buckets | sed 's/ //g' | jq '.Grants | length'`
	if [ $length -gt 1 ];
	then
		for grantee in $bucketAcls;
		do
			#echo Grantee:$grantee
			granteeType=`echo $grantee | jq '.Grantee.Type' | sed 's/"//g'`
			granteeURI=`echo $grantee | jq '.Grantee.URI' | sed 's/"//g'`
			granteePermission=`echo $grantee | jq '.Permission' | sed 's/"//g'`
			containsElement "$granteePermission" "${flaggedPermissions[@]}"
			contains=`echo $?`
			#echo granteeType:$granteeType : granteeURI:$granteeURI : granteePermission:$granteePermission : contains:$contains
			if [ -n "$granteeURI" ];
			then
				if [[ "$granteeType" == "Group" && "$granteeURI" == "$publicURI" && "$contains" == "1" ]];
				then
				    echo "Warning: Flagged permission ($granteePermission) found for $bucketName under Account Owner:$bucketOwner"
				    bucketPutAclResponse=`aws s3api put-bucket-acl --bucket $bucketName --acl private --profile saml`
				    echo "Bucket $bucketName ACL was tried to set to Private."
				    if [ -n "$bucketPutAclResponse" ]; 
				    then
				    	echo "Error: Setting bucket $bucketName ACL to Private may have failed. Reason: $bucketPutAclResponse"
				    else
				    	echo "Setting bucket $bucketName ACL to Private succeeded."
				    fi
				fi
			fi
		done;
	fi
done;
