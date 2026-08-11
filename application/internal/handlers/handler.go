package handlers

import (
	"database/sql"

	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/config"

	"github.com/aws/aws-sdk-go-v2/service/sqs"
)

type Handler struct {
	DB        *sql.DB
	SQSClient *sqs.Client
	Config    config.Config
}