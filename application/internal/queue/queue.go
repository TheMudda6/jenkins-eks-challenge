package queue

import (
	"context"

	appconfig "github.com/TheMudda6/jenkins-eks-challenge/application/internal/config"

	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
)

func NewClient(cfg appconfig.Config) (*sqs.Client, error) {

	awsCfg, err := awsconfig.LoadDefaultConfig(
		context.TODO(),
		awsconfig.WithRegion(cfg.AWSRegion),
	)

	if err != nil {
		return nil, err
	}

	client := sqs.NewFromConfig(awsCfg)

	return client, nil
}