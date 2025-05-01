// registrations/index.js
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();
const uuid = require('uuid'); // Para generar IDs únicos

exports.handler = async (event) => {
    try {
        // 1. Parsear el cuerpo de la solicitud
        const requestBody = JSON.parse(event.body);
        const { email, nombre, tipoUsuario } = requestBody;

        // 2. Validaciones básicas
        if (!email || !nombre || !tipoUsuario) {
            return {
                statusCode: 400,
                body: JSON.stringify({ 
                    message: 'Faltan campos requeridos: email, nombre, tipoUsuario' 
                })
            };
        }

        // 3. Verificar si el usuario ya existe
        const usuarioExistente = await dynamodb.get({
            TableName: process.env.REGISTRATIONS_TABLE,
            Key: { email }
        }).promise();

        if (usuarioExistente.Item) {
            return {
                statusCode: 409,
                body: JSON.stringify({ 
                    message: 'El usuario ya está registrado',
                    userId: usuarioExistente.Item.userId
                })
            };
        }

        // 4. Crear nuevo registro
        const nuevoUsuario = {
            userId: uuid.v4(),
            email,
            nombre,
            tipoUsuario,
            fechaRegistro: new Date().toISOString(),
            estado: 'activo',
            ultimoAcceso: new Date().toISOString()
        };

        // 5. Guardar en DynamoDB
        await dynamodb.put({
            TableName: process.env.REGISTRATIONS_TABLE,
            Item: nuevoUsuario
        }).promise();

        // 6. Registrar en CloudWatch
        console.log(`Nuevo usuario registrado: ${email}`);

        // 7. Respuesta exitosa
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
        // Manejo de errores
        console.error('Error en el registro:', error);
        
        return {
            statusCode: 500,
            body: JSON.stringify({ 
                message: 'Error interno del servidor',
                error: error.message 
            })
        };
    }
};