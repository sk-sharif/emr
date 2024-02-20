## AWS Step Function Service Role
resource "aws_iam_role" "step_function_service_role" {
  name = "step_function_service_role"
  assume_role_policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Effect": "Allow",
          "Principal": {
            "Service": "elasticmapreduce.amazonaws.com"
          }
        }
      ]
    }
  EOF
}


## Create a policy for the AllowServiceLinkedRole
resource "aws_iam_policy" "AllowServiceLinkedRole" {
     name = "StepFunctionAllowServiceLinkedRole"
     policy = <<-EOF
     {
          "Version": "2012-10-17",
          "Statement": [
               {
                    "Condition": {
                         "StringLike": {
                              "iam:AWSServiceName": [
                                   "elasticmapreduce.amazonaws.com",
                                   "elasticmapreduce.amazonaws.com.cn"
                              ]
                         }
                    },
                    "Action": [
                         "iam:CreateServiceLinkedRole",
                         "iam:PutRolePolicy"
                    ],
                    "Resource": "arn:aws:iam::*:role/aws-service-role/elasticmapreduce.amazonaws.com*/AWSServiceRoleForEMRCleanup*",
                    "Effect": "Allow"
               }
          ]
     }
     EOF
}

# Attach AllowServiceLinkedRole Policy
resource "aws_iam_role_policy_attachment" "allow_service_linked_role_attachment" {
  policy_arn = aws_iam_policy.AllowServiceLinkedRole.arn
  role       = aws_iam_role.step_function_service_role.name
}

# Attach AmazonElasticMapReduceRole Policy
resource "aws_iam_role_policy_attachment" "emr_role_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
  role       = aws_iam_role.step_function_service_role.name
}


# 2 role

## EC2 Instance Profile role
resource "aws_iam_role" "instance_profile_role" {
     name = "instance_profile_role"
     assume_role_policy = <<-EOF
     {
          "Version": "2008-10-17",
          "Statement": [
               {
                    "Effect": "Allow",
                    "Principal": {
                         "Service": "ec2.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
               }
          ]
     }
     EOF
}

## Create Ec2 EMR Role Policy
resource "aws_iam_policy" "EMR_EC2_instance_profile_policy" {
     name = "EMR_EC2_instance_profile_policy"
     policy = <<-EOF
     {
          "Version": "2012-10-17",
          "Statement": [
               {
                    "Action": [
                         "s3:*"
                    ],
                    "Resource": "${aws_s3_bucket.stepfuctionbucket.arn}",
                    "Effect": "Allow"
               }
          ]
     }
     EOF
}

# Attaching EC2 EMR Instance Role Policy to the Instance Profile
resource "aws_iam_role_policy_attachment" "attach_emr_policy_to_role" {
     role = aws_iam_role.instance_profile_role.name
     policy_arn = aws_iam_policy.EMR_EC2_instance_profile_policy.arn
}


# 3 role

# AWS Step Function Role
resource "aws_iam_role" "step_function_role" {
  name = "step_function_role"
  assume_role_policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Effect": "Allow",
          "Principal": {
            "Service": "states.amazonaws.com"
          }
        }
      ]
    }
  EOF
}

## Create a policy for the StatesExecutionPolicy
resource "aws_iam_policy" "StatesExecutionPolicy" {
     name = "StepFunctionStatesExecutionPolicy"
     policy = <<-EOF
     {
          "Version": "2012-10-17",
          "Statement": [
               {
                    "Action": [
                         "iam:PassRole"
                    ],
                    "Resource": [
                         "${aws_iam_role.step_function_service_role.arn}",
                         "${aws_iam_role.instance_profile_role.arn}"
                    ],
                    "Effect": "Allow"
               },
               {
                    "Action": [
                         "elasticmapreduce:RunJobFlow",
                         "elasticmapreduce:TerminateJobFlows",
                         "elasticmapreduce:DescribeCluster",
                         "elasticmapreduce:AddJobFlowSteps",
                         "elasticmapreduce:DescribeStep"
                    ],
                    "Resource": "*",
                    "Effect": "Allow"
               }
          ]
     }
     EOF
}

## Create IAM policy for the Full Access
resource "aws_iam_policy" "IAMFullPolicy" {
     name = "IAMFullAccessPolicy"
     policy = <<-EOF
     {
          "Version": "2012-10-17",
          "Statement": [
               {
                    "Effect": "Allow",
                    "Action": [
                         "iam:*",
                         "organizations:DescribeAccount",
                         "organizations:DescribeOrganization",
                         "organizations:DescribeOrganizationalUnit",
                         "organizations:DescribePolicy",
                         "organizations:ListChildren",
                         "organizations:ListParents",
                         "organizations:ListPoliciesForTarget",
                         "organizations:ListRoots",
                         "organizations:ListPolicies",
                         "organizations:ListTargetsForPolicy"
                    ],
                    "Resource": "*"
               }
          ]
     }
     EOF
}

# Attach IAM Full policy to Step Function role
resource "aws_iam_role_policy_attachment" "IAM_Full_policy_to_role" {
     role = aws_iam_role.step_function_role.id
     policy_arn = aws_iam_policy.IAMFullPolicy.arn
}

# Attach State Execution Policy to role
resource "aws_iam_role_policy_attachment" "attach_state_execution_policy_to_role" {
     role = aws_iam_role.step_function_role.id
     policy_arn = aws_iam_policy.StatesExecutionPolicy.arn
}

# Attach AllowServiceLinkedRole Policy to step function
resource "aws_iam_role_policy_attachment" "allow_service_linked_role_attachment_step_function" {
  role       = aws_iam_role.step_function_role.id
  policy_arn = aws_iam_policy.AllowServiceLinkedRole.arn
}

resource "aws_iam_instance_profile" "emr_instance_profile" {
  name = "emr-instance-profile"
  role = aws_iam_role.instance_profile_role.name
}

## Create S3 Bucket to store logs of step function
resource "aws_s3_bucket" "stepfuctionbucket" {
    bucket = "stepfunctions-emrproject-pocucket"  # Replace with a unique name for your S3 bucket
    acl = "private"
    tags = {
        Name        = "stepfunctions-emrproject-pocbucket"
        Environment = "POC"
    }
}

resource "aws_s3_bucket_object" "logs_folder" {
     bucket = aws_s3_bucket.stepfuctionbucket.bucket
     key    = "logs/"  # This creates a folder named "logs" inside the bucket
     acl    = "private"
}


## Create State Function to create EMR Cluster
resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = "my-state-machine"
  role_arn = aws_iam_role.step_function_role.arn

  definition = <<EOF
  {
     "Comment": "An example of the Amazon States Language for running jobs on Amazon EMR",
     "StartAt": "Create an EMR cluster",
     "States": {
          "Create an EMR cluster": {
               "Type": "Task",
               "Resource": "arn:aws:states:::elasticmapreduce:createCluster.sync",
               "Parameters": {
                    "Name": "TerraformEMRCluster",
                    "VisibleToAllUsers": true,
                    "ReleaseLabel": "emr-7.0.0",
                    "Applications": [
                         {
                              "Name": "Hive"
                         }
                    ],
                    "ServiceRole": "${aws_iam_role.step_function_service_role.id}",
                    "JobFlowRole": "${aws_iam_instance_profile.emr_instance_profile.arn}",
                    "LogUri": "s3://${aws_s3_bucket.stepfuctionbucket.bucket}/logs/",
                    "Instances": {
                         "KeepJobFlowAliveWhenNoSteps": true,
                         "InstanceFleets": [
                              {
                                   "Name": "MyMasterFleet",
                                   "InstanceFleetType": "MASTER",
                                   "TargetOnDemandCapacity": 1,
                                   "InstanceTypeConfigs": [
                                        {
                                             "InstanceType": "m5.xlarge"
                                        }
                                   ]
                              },
                              {
                                   "Name": "MyCoreFleet",
                                   "InstanceFleetType": "CORE",
                                   "TargetOnDemandCapacity": 1,
                                   "InstanceTypeConfigs": [
                                        {
                                             "InstanceType": "m5.xlarge"
                                        }
                                   ]
                              }
                         ]
                    }
               },
               "ResultPath": "$.cluster",
               "Next": "Run first step"
          },
          "Run first step": {
               "Type": "Task",
               "Resource": "arn:aws:states:::elasticmapreduce:addStep.sync",
               "Parameters": {
                    "ClusterId.$": "$.cluster.ClusterId",
                    "Step": {
                         "Name": "My first EMR step",
                         "ActionOnFailure": "CONTINUE",
                         "HadoopJarStep": {
                              "Jar": "command-runner.jar",
                              "Args": [
                                   "bash",
                                   "-c",
                                   "ls"
                              ]
                         }
                    }
               },
               "Retry": [
                    {
                         "ErrorEquals": [
                              "States.ALL"
                         ],
                         "IntervalSeconds": 1,
                         "MaxAttempts": 3,
                         "BackoffRate": 2
                    }
               ],
               "ResultPath": "$.firstStep",
               "End": true
          }
     }
  }
  EOF
}
