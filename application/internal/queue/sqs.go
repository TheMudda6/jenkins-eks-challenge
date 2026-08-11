package queue

import (
	"context"

	"github.com/aws/aws-sdk-go-v2/aws"
	
	"github.com/aws/aws-sdk-go-v2/service/sqs"	
)

func PublishOrderCreated(client *sqs.Client, queueURL string, message string) error {

	_, err := client.SendMessage(context.TODO(), &sqs.SendMessageInput{
		QueueUrl:    aws.String(queueURL),
		MessageBody: aws.String(message),
	})

	if err != nil {
		return err
	}

	return nil
}