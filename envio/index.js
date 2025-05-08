const AWS = require('aws-sdk');
const ses = new AWS.SES();
const sqs = new AWS.SQS();

exports.handler = async (event) => {
  try {
    for (const record of event.Records) {
      const message = JSON.parse(record.body);
      const { email, subject, body } = message;

      const params = {
        Source: process.env.SES_EMAIL_IDENTITY,  // Correo verificado en SES
        Destination: {
          ToAddresses: [email]
        },
        Message: {
          Subject: {
            Data: subject
          },
          Body: {
            Text: {
              Data: body
            }
          }
        }
      };

      // Enviar el correo con SES
      await ses.sendEmail(params).promise();

      // Eliminar el mensaje de la cola después de procesarlo
      const deleteParams = {
        QueueUrl: process.env.SQS_QUEUE_URL,
        ReceiptHandle: record.receiptHandle
      };
      await sqs.deleteMessage(deleteParams).promise();
      
      console.log(`Correo enviado a: ${email}`);
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Correo(s) enviado(s) exitosamente'
      })
    };
  } catch (error) {
    console.error('Error al enviar correo:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: 'Error interno al enviar el correo',
        error: error.message
      })
    };
  }
};
