# terraform/default.nix
{ ... }:

{
  imports = [
    ./vpc.nix
    ./ecs.nix
  ];

  config = { config, lib, ... }:
    let
      inherit (lib)
        optionalAttrs foldl' recursiveUpdate
        mapAttrs mapAttrsToList attrValues imap0;

      cfg = config.services.ecsFargate;
      rn  = n: "fargate_${n}";

      containerResources = mapAttrs (name: c:
        let r = rn name; in
        foldl' recursiveUpdate {} [

          { resource.aws_cloudwatch_log_group.${r} = {
              name              = "/ecs/${cfg.clusterName}/${name}";
              retention_in_days = c.logRetentionDays;
              tags              = cfg.tags;
            };
          }

          { resource.aws_iam_role."${r}_execution" = {
              name = "${cfg.clusterName}-${name}-execution";
              assume_role_policy = builtins.toJSON {
                Version = "2012-10-17";
                Statement = [{
                  Effect    = "Allow";
                  Principal = { Service = "ecs-tasks.amazonaws.com"; };
                  Action    = "sts:AssumeRole";
                }];
              };
              tags = cfg.tags;
            };
            resource.aws_iam_role_policy_attachment."${r}_execution_policy" = {
              role       = "\${aws_iam_role.${r}_execution.name}";
              policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy";
            };
          }

          (optionalAttrs (c.taskRoleArn == null) (
            foldl' recursiveUpdate {} ([{
              resource.aws_iam_role."${r}_task" = {
                name = "${cfg.clusterName}-${name}-task";
                assume_role_policy = builtins.toJSON {
                  Version = "2012-10-17";
                  Statement = [{
                    Effect    = "Allow";
                    Principal = { Service = "ecs-tasks.amazonaws.com"; };
                    Action    = "sts:AssumeRole";
                  }];
                };
                tags = cfg.tags;
              };
            }] ++ (imap0 (i: arn: {
              resource.aws_iam_role_policy_attachment."${r}_task_extra_${toString i}" = {
                role       = "\${aws_iam_role.${r}_task.name}";
                policy_arn = arn;
              };
            }) c.extraPolicies))
          ))

          { resource.aws_ecs_task_definition.${r} = {
              family                   = "${cfg.clusterName}-${name}";
              requires_compatibilities = [ "FARGATE" ];
              network_mode             = "awsvpc";
              cpu                      = toString c.cpu;
              memory                   = toString c.memory;
              execution_role_arn       = "\${aws_iam_role.${r}_execution.arn}";
              task_role_arn            =
                if c.taskRoleArn != null then c.taskRoleArn
                else "\${aws_iam_role.${r}_task.arn}";
              container_definitions = builtins.toJSON ([
                ({
                  name      = name;
                  image     = c.image;
                  cpu       = c.cpu;
                  memory    = c.memory;
                  essential = true;
                  logConfiguration = {
                    logDriver = "awslogs";
                    options = {
                      "awslogs-group"         = "/ecs/${cfg.clusterName}/${name}";
                      "awslogs-region"        = cfg.region;
                      "awslogs-stream-prefix" = "ecs";
                    };
                  };
                }
                // optionalAttrs (c.port != null)      { portMappings = [{ containerPort = c.port; protocol = "tcp"; }]; }
                // optionalAttrs (c.command != null)   { command = c.command; }
                // optionalAttrs (c.environment != {}) { environment = mapAttrsToList (k: v: { name = k; value = v; }) c.environment; }
                // optionalAttrs (c.secrets != {})     { secrets = mapAttrsToList (k: v: { name = k; valueFrom = v; }) c.secrets; }
                )
              ]);
              tags = cfg.tags;
            };
          }

          { resource.aws_security_group.${r} = {
              name        = "${cfg.clusterName}-${name}-svc";
              description = "ECS service SG for ${name}";
              vpc_id      = cfg.vpc.id;
              tags        = cfg.tags;
              egress = [{ from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = [ "0.0.0.0/0" ]; }];
            };
          }

          (optionalAttrs (c.public && c.port != null) (foldl' recursiveUpdate {} [
            { resource.aws_security_group."${r}_alb" = {
                name        = "${cfg.clusterName}-${name}-alb";
                description = "ALB SG for ${name}";
                vpc_id      = cfg.vpc.id;
                tags        = cfg.tags;
                ingress = [{ from_port = 80; to_port = 80; protocol = "tcp"; cidr_blocks = [ "0.0.0.0/0" ]; }];
                egress  = [{ from_port = 0;  to_port = 0;  protocol = "-1"; cidr_blocks = [ "0.0.0.0/0" ]; }];
              };
            }
            { resource.aws_lb.${r} = {
                name               = "${cfg.clusterName}-${name}";
                internal           = false;
                load_balancer_type = "application";
                security_groups    = [ "\${aws_security_group.${r}_alb.id}" ];
                subnets            = cfg.vpc.publicSubnetIds;
                tags               = cfg.tags;
              };
            }
            { resource.aws_lb_target_group.${r} = {
                name        = "${cfg.clusterName}-${name}";
                port        = c.port;
                protocol    = c.protocol;
                vpc_id      = cfg.vpc.id;
                target_type = "ip";
                tags        = cfg.tags;
              } // optionalAttrs (c.healthCheck != null) {
                health_check = {
                  path                = c.healthCheck.path;
                  interval            = c.healthCheck.interval;
                  timeout             = c.healthCheck.timeout;
                  healthy_threshold   = c.healthCheck.healthy;
                  unhealthy_threshold = c.healthCheck.unhealthy;
                  matcher             = c.healthCheck.matcher;
                };
              };
            }
            { resource.aws_lb_listener.${r} = {
                load_balancer_arn = "\${aws_lb.${r}.arn}";
                port              = 80;
                protocol          = "HTTP";
                default_action    = [{ type = "forward"; target_group_arn = "\${aws_lb_target_group.${r}.arn}"; }];
              };
              resource.aws_security_group_rule."${r}_alb_ingress" = {
                type                     = "ingress";
                from_port                = c.port;
                to_port                  = c.port;
                protocol                 = "tcp";
                security_group_id        = "\${aws_security_group.${r}.id}";
                source_security_group_id = "\${aws_security_group.${r}_alb.id}";
              };
            }
          ]))

          { resource.aws_ecs_service.${r} = {
              name            = "${cfg.clusterName}-${name}";
              cluster         = "\${aws_ecs_cluster.${cfg.clusterName}.id}";
              task_definition = "\${aws_ecs_task_definition.${r}.arn}";
              desired_count   = c.scaling.min;
              launch_type     = "FARGATE";
              network_configuration = [{
                subnets          = cfg.vpc.privateSubnetIds;
                security_groups  = [ "\${aws_security_group.${r}.id}" ];
                assign_public_ip = c.assignPublicIp;
              }];
            } // optionalAttrs (c.public && c.port != null) {
              load_balancer = [{
                target_group_arn = "\${aws_lb_target_group.${r}.arn}";
                container_name   = name;
                container_port   = c.port;
              }];
              depends_on = [ "aws_lb_listener.${r}" ];
            };
          }

          { resource.aws_appautoscaling_target.${r} = {
              max_capacity       = c.scaling.max;
              min_capacity       = c.scaling.min;
              resource_id        = "service/${cfg.clusterName}/${cfg.clusterName}-${name}";
              scalable_dimension = "ecs:service:DesiredCount";
              service_namespace  = "ecs";
              depends_on         = [ "aws_ecs_service.${r}" ];
            };
            resource.aws_appautoscaling_policy."${r}_cpu" = {
              name               = "${cfg.clusterName}-${name}-cpu";
              policy_type        = "TargetTrackingScaling";
              resource_id        = "\${aws_appautoscaling_target.${r}.resource_id}";
              scalable_dimension = "\${aws_appautoscaling_target.${r}.scalable_dimension}";
              service_namespace  = "\${aws_appautoscaling_target.${r}.service_namespace}";
              target_tracking_scaling_policy_configuration = [{
                target_value = c.scaling.cpuTarget;
                predefined_metric_specification = [{ predefined_metric_type = "ECSServiceAverageCPUUtilization"; }];
              }];
            };
          }

          (optionalAttrs (c.scaling.memTarget != null) {
            resource.aws_appautoscaling_policy."${r}_mem" = {
              name               = "${cfg.clusterName}-${name}-mem";
              policy_type        = "TargetTrackingScaling";
              resource_id        = "\${aws_appautoscaling_target.${r}.resource_id}";
              scalable_dimension = "\${aws_appautoscaling_target.${r}.scalable_dimension}";
              service_namespace  = "\${aws_appautoscaling_target.${r}.service_namespace}";
              target_tracking_scaling_policy_configuration = [{
                target_value = c.scaling.memTarget;
                predefined_metric_specification = [{ predefined_metric_type = "ECSServiceAverageMemoryUtilization"; }];
              }];
            };
          })

        ]
      ) cfg.containers;

    in
    {
      terraform.required_providers.aws = {
        source  = "hashicorp/aws";
        version = "~> 5.0";
      };

      provider.aws.region = "eu-west-1";

      networking.vpcs.app = {
        cidr              = "10.0.0.0/16";
        availabilityZones = [ "eu-west-1a" "eu-west-1b" ];
        natGateway        = "single";
        tags              = { ManagedBy = "terraform"; };
      };

      services.ecsFargate = {
        enable      = true;
        clusterName = "my-app";
        region      = "eu-west-1";
        tags        = { ManagedBy = "terraform"; };
        vpc         = config.networking.vpcs.app.ref;

        containers.api = {
          image         = "123456789.dkr.ecr.eu-west-1.amazonaws.com/api:latest";
          cpu           = 512;
          memory        = 1024;
          port          = 8080;
          public        = true;
          environment   = { NODE_ENV = "production"; };
          healthCheck   = { path = "/health"; };
          scaling       = { min = 2; max = 10; cpuTarget = 60; };
          extraPolicies = [ "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess" ];
        };

        containers.worker = {
          image       = "123456789.dkr.ecr.eu-west-1.amazonaws.com/worker:latest";
          cpu         = 256;
          memory      = 512;
          environment.QUEUE_URL = "https://sqs.eu-west-1.amazonaws.com/123/my-queue";
        };
      };
    }
    // optionalAttrs cfg.enable (
      foldl' recursiveUpdate {} (
        [{ resource.aws_ecs_cluster.${cfg.clusterName} = {
             name = cfg.clusterName;
             tags = cfg.tags;
             setting = [{ name = "containerInsights"; value = "enabled"; }];
           };
           output.ecs_cluster_name.value = "\${aws_ecs_cluster.${cfg.clusterName}.name}";
           output.ecs_cluster_arn.value  = "\${aws_ecs_cluster.${cfg.clusterName}.arn}";
        }]
        ++ attrValues containerResources
        ++ mapAttrsToList (name: c:
             optionalAttrs (c.public && c.port != null) {
               output."${name}_alb_dns".value = "\${aws_lb.${rn name}.dns_name}";
             }
           ) cfg.containers
      )
    );
}