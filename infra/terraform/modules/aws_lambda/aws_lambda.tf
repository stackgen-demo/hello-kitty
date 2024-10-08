resource "aws_lambda_function" "this" {
  architectures = [var.architecture]
  function_name = var.function_name
  description   = var.description
  role          = var.role
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size

  # using local file for lambda
  filename         = var.filename != "" ? var.filename : null
  source_code_hash = var.filename != "" && var.filename != null ? filemd5(var.filename) : null

  # using s3 bucket for lambda
  s3_bucket         = var.s3_bucket != "" ? var.s3_bucket : null
  s3_key            = var.s3_key
  s3_object_version = var.s3_object_version

  dynamic "logging_config" {
    for_each = var.log_format != null ? [1] : []
    content {
      log_group        = var.log_group_name
      log_format       = var.log_format
      system_log_level = var.system_log_level
    }
  }

  environment {
    variables = var.environment_variables
  }

  tags = var.tags

}

resource "aws_lambda_function_url" "this" {
  count              = var.create_function_url ? 1 : 0
  function_name      = aws_lambda_function.this.function_name
  authorization_type = var.create_function_url && var.authorization_type == null ? "NONE" : var.authorization_type

  dynamic "cors" {
    for_each = var.cors
    content {
      allow_origins     = cors.value.allow_origins
      allow_methods     = cors.value.allow_methods
      allow_headers     = cors.value.allow_headers
      max_age           = cors.value.max_age
      allow_credentials = cors.value.allow_credentials
    }
  }
}



resource "aws_lambda_event_source_mapping" "this" {
  count = length(var.event_source_mapping)
  # common for all event sources
  event_source_arn  = var.event_source_mapping[count.index].event_source_arn
  function_name     = aws_lambda_function.this.arn
  starting_position = var.event_source_mapping[count.index].starting_position
  batch_size        = var.event_source_mapping[count.index].batch_size
  enabled           = var.event_source_mapping[count.index].enabled

  # for MSK
  topics = [var.event_source_mapping[count.index].msk_topic]

  # for MQ
  queues = [var.event_source_mapping[count.index].mq_queue]

  # for kinesis and dynamodb
  bisect_batch_on_function_error = var.event_source_mapping[count.index].bisect_batch_on_function_error
  maximum_record_age_in_seconds  = var.event_source_mapping[count.index].maximum_record_age_in_seconds
  maximum_retry_attempts         = var.event_source_mapping[count.index].maximum_retry_attempts
  parallelization_factor         = var.event_source_mapping[count.index].parallelization_factor

  # for kinsesis dynamodb and kafka
  destination_config {
    on_failure {
      destination_arn = var.event_source_mapping[count.index].on_failure_destination_arn
    }
  }
  maximum_batching_window_in_seconds = var.event_source_mapping[count.index].maximum_batching_window_in_seconds

  # for SQS,kinesis and dynamodb
  filter_criteria {
    filter {
      pattern = var.event_source_mapping[count.index].filter_pattern
    }
  }

  # for dynamodb
  document_db_event_source_config {
    collection_name = var.event_source_mapping[count.index].collection_name
    database_name   = var.event_source_mapping[count.index].database_name
    full_document   = var.event_source_mapping[count.index].full_document
  }
  # for SQS 
  scaling_config {
    maximum_concurrency = var.event_source_mapping[count.index].maximum_concurrency
  }
}

# in case of asyncronous invocation onfigure permission for lambda to invoke the destination
# allowed destination for asyncronous invocation are SQS, SNS and Lambda function, event bridge
resource "aws_lambda_permission" "this" {
  count         = length(var.event_source_mapping)
  statement_id  = var.event_source_mapping[count.index].principal + count.index
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = var.event_source_mapping[count.index].principal
  source_arn    = var.event_source_arn
}








