const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();
const uuid = require('uuid');
const crypto = require('crypto');

exports.handler = async (event) => {
    try {
        // 1. Parsear parámetros de la solicitud
        const requestBody = JSON.parse(event.body);
        const { userId, tipoCertificado, validezDias } = requestBody;

        // 2. Validaciones básicas
        if (!userId || !tipoCertificado || !validezDias) {
            return {
                statusCode: 400,
                body: JSON.stringify({
                    message: 'Faltan campos requeridos: userId, tipoCertificado, validezDias'
                })
            };
        }

        // 3. Generar certificado único
        const certificateId = uuid.v4();
        const fechaEmision = new Date().toISOString();
        const fechaExpiracion = new Date(Date.now() + validezDias * 86400000).toISOString();
        
        // 4. Generar hash seguro para el certificado
        const certificadoHash = crypto
            .createHash('sha256')
            .update(`${userId}-${certificateId}-${fechaEmision}`)
            .digest('hex');

        // 5. Crear objeto del certificado
        const nuevoCertificado = {
            certificateId,
            userId,
            tipoCertificado,
            fechaEmision,
            fechaExpiracion,
            certificadoHash,
            estado: 'activo',
            intentosValidacion: 0
        };

        // 6. Guardar en DynamoDB
        await dynamodb.put({
            TableName: process.env.CERTIFICATES_TABLE,
            Item: nuevoCertificado
        }).promise();

        // 7. Registrar en CloudWatch
        console.log(`Nuevo certificado generado: ${certificateId}`);

        // 8. Respuesta exitosa (sin enviar el hash completo por seguridad)
        return {
            statusCode: 201,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                message: 'Certificado generado exitosamente',
                certificado: {
                    certificateId,
                    userId,
                    tipoCertificado,
                    fechaEmision,
                    fechaExpiracion,
                    estado: 'activo'
                },
                hashPreview: certificadoHash.substring(0, 8) + '...' // Mostrar solo parte del hash
            })
        };

    } catch (error) {
        console.error('Error en generación de certificado:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({
                message: 'Error interno en generación de certificado',
                error: error.message
            })
        };
    }
};