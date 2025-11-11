# Live AI Review Assistant

## Automated Code Review System Powered by Fine-tuned Codegen-350M

### Problem
Traditional code reviews are time-consuming, rely heavily on individual reviewer experience, and often delay software delivery. Existing AI-powered solutions typically require sharing private source code with external cloud servers, posing significant security and confidentiality risks for proprietary projects.

### Solution
The "Live AI Review Assistant" project addresses these challenges by providing an automated, secure, and efficient code review system. It leverages a fine-tuned Codegen-350M large language model to analyze Python code in real-time and generate intelligent review comments. The entire system operates within a private AWS infrastructure, ensuring full data privacy and control.

## Key Features

*   **Automated Code Analysis**: Fine-tuned Codegen-350M model generates coherent, context-aware code review comments.
*   **Secure & Private**: Operates entirely within a private AWS infrastructure, eliminating the need to send source code to external systems.
*   **Real-time GitHub Integration**: Automatically processes GitHub pull request events and posts review comments directly.
*   **Scalable & Cost-Effective**: Utilizes serverless AWS components (Lambda, ECS Fargate, SQS, S3) for high scalability and low maintenance.
*   **MLOps Practices**: Employs MLflow for comprehensive experiment tracking, logging, and reproducibility of training runs.
*   **Python-Focused**: Currently specialized in reviewing Python code, with potential for future expansion.

## Technologies Used

### Codegen-350M Fine-Tuning
*   **Programming Language**: Python
*   **ML Frameworks**: PyTorch, Hugging Face Transformers, PEFT (LoRA)
*   **Data Management**: Datasets, Pandas, NumPy
*   **Experiment Tracking**: MLflow
*   **Version Control**: GitHub

### AWS Architecture & Infrastructure
*   **Programming Languages**: Python, HCL (for Terraform), Shell
*   **Infrastructure Management**: Terraform (Infrastructure as Code)
*   **Containerization**: Docker
*   **AWS Services**: VPC, S3, CloudWatch, SQS, Lambda, Secrets Manager, API Gateway, ECR, ECS Fargate, DynamoDB, EventBridge Pipes, Step Functions

## Architecture Overview
![architecture_diagram](https://i.ibb.co/VnGnvb8/architecture.png)

## How It Works (System Flow)

1.  **GitHub Webhooks**: GitHub triggers a webhook on pull request events (e.g., new PR, update).
2.  **Webhook API (AWS Lambda)**: A Lambda function receives, authenticates, and parses the event, sending basic PR info to an SQS queue.
3.  **Review Events Queue (SQS)**: Acts as a buffer, ensuring asynchronous processing and resilience.
4.  **Dispatcher (AWS Lambda)**: Reads from the queue, stores code diffs in S3, and forwards tasks for analysis.
5.  **Review Worker (ECS Fargate Task)**:
    *   Retrieves GitHub credentials from Secrets Manager.
    *   Loads the fine-tuned Codegen-350M model adapter from S3.
    *   Generates code review comments based on the code diff.
6.  **Comment Publication (GitHub API)**: The Review Worker posts the generated comments back to the GitHub pull request.
7.  **Model Adapters Storage (S3)**: Versioned S3 bucket for storing model adapters, ensuring reproducibility.
8.  **Idempotency & Reliability (DynamoDB)**: Tracks processed events to prevent duplicates and ensure data consistency.

This automated flow ensures fast, consistent, and secure code review, allowing developers to focus on core development.
