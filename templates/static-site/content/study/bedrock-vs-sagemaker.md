---
title: Amazon Bedrock vs. Amazon SageMaker AI
weight: 2
extra:
  topic_id: bedrock-vs-sagemaker
  domain_id: 3
  estimated_reading_time: 6 min
  summary:
    - Bedrock is a serverless API service for foundation models.
    - SageMaker is an end-to-end platform for building, training and deploying custom models.
  comparison_table:
    headers: [Feature, Bedrock, SageMaker]
    rows:
      - [Infrastructure, Serverless, Managed instances]
      - [Primary choice, Pre-trained foundation models via API, Custom model building]
  exam_tip: Choose Bedrock for quick access to foundation models without managing servers.
  exam_trap: Prompts sent to Bedrock are not used to re-train the base models.
---

Pick by how much control over the model you need.
