const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();
const uuid = require('uuid');

exports.handler = async (event) => {
    try {
        // Validar si el cuerpo existe
        if (!event.body) {
            return {
                statusCode: 400,
                body: JSON.stringify({ message: 'El cuerpo de la solicitud está vacío' })
            };
        }

        // Parsear y validar campos
        const requestBody = JSON.parse(event.body);
        const { email, nombre, tipoUsuario } = requestBody;

        if (!email || !nombre || !tipoUsuario) {
            return {
                statusCode: 400,
                body: JSON.stringify({ 
                    message: 'Faltan campos requeridos: email, nombre, tipoUsuario' 
                })
            };
        }

        // 1. Verificar si el usuario existe usando el ÍNDICE GLOBAL SECUNDARIO
        const usuarioExistente = await dynamodb.query({
            TableName: process.env.REGISTRATIONS_TABLE,
            IndexName: "EmailIndex", // Usar el GSI definido en Terraform
            KeyConditionExpression: "email = :email",
            ExpressionAttributeValues: { ":email": email }
        }).promise();

        if (usuarioExistente.Items?.length > 0) {
            return {
                statusCode: 409,
                body: JSON.stringify({ 
                    message: 'El usuario ya está registrado',
                    userId: usuarioExistente.Items[0].userId
                })
            };
        }

        // 2. Crear nuevo usuario con mapeo correcto
        const nuevoUsuario = {
            userId: uuid.v4(), // Clave de partición
            email: email, // Clave de rango
            nombre: nombre,
            accountType: tipoUsuario, // Nombre correcto del campo en DynamoDB
            fechaRegistro: new Date().toISOString(),
            estado: 'activo',
            ultimoAcceso: new Date().toISOString()
        };

        // 3. Guardar en DynamoDB
        await dynamodb.put({
            TableName: process.env.REGISTRATIONS_TABLE,
            Item: nuevoUsuario
        }).promise();

        console.log(`Registro exitoso: ${email}`);
        
        return {
            statusCode: 201,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                message: 'Registro exitoso',
                usuario: {
                    userId: nuevoUsuario.userId,
                    email: nuevoUsuario.email,
                    nombre: nuevoUsuario.nombre
                }
            })
        };

    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ 
                message: 'Error interno del servidor',
                error: error.message 
            })
        };
    }
};