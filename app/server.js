const express = require('express');
const os = require('os');
const app = express();

const PORT = process.env.PORT || 3000;
const ENVIRONMENT = process.env.ENVIRONMENT || 'UNKNOWN';
const VERSION = process.env.VERSION || '1.0.0';

// Middleware
app.use(express.json());

// Rutas de salud
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'UP',
    timestamp: new Date().toISOString(),
    environment: ENVIRONMENT
  });
});

// Ruta de estado detallado
app.get('/status', (req, res) => {
  res.status(200).json({
    status: 'UP',
    environment: ENVIRONMENT,
    version: VERSION,
    hostname: os.hostname(),
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// Ruta raíz
app.get('/', (req, res) => {
  res.status(200).send(`
    <!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Blue-Green Deployment Demo</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
          display: flex;
          justify-content: center;
          align-items: center;
          min-height: 100vh;
          transition: all 0.3s ease;
        }
        body.blue {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        body.green {
          background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
        }
        .container {
          text-align: center;
          background: rgba(255, 255, 255, 0.95);
          padding: 60px 40px;
          border-radius: 20px;
          box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
          max-width: 600px;
          animation: slideUp 0.6s ease;
        }
        @keyframes slideUp {
          from {
            opacity: 0;
            transform: translateY(30px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }
        h1 {
          color: #333;
          margin-bottom: 20px;
          font-size: 2.5em;
        }
        .badge {
          display: inline-block;
          padding: 12px 24px;
          border-radius: 50px;
          font-weight: bold;
          font-size: 1.2em;
          margin: 20px 0;
          color: white;
        }
        .badge.blue {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .badge.green {
          background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
        }
        .info-box {
          background: #f5f5f5;
          padding: 20px;
          border-radius: 10px;
          margin: 20px 0;
          text-align: left;
        }
        .info-box p {
          margin: 10px 0;
          color: #666;
          font-family: 'Courier New', monospace;
        }
        .info-box strong {
          color: #333;
        }
        .version-info {
          font-size: 0.9em;
          color: #999;
          margin-top: 30px;
        }
        .refresh-btn {
          background: #667eea;
          color: white;
          border: none;
          padding: 12px 30px;
          border-radius: 25px;
          font-size: 1em;
          cursor: pointer;
          transition: all 0.3s ease;
          margin-top: 20px;
        }
        .refresh-btn:hover {
          background: #764ba2;
          transform: scale(1.05);
        }
      </style>
    </head>
    <body class="${ENVIRONMENT.toLowerCase()}">
      <div class="container">
        <h1>🚀 Blue-Green Deployment</h1>
        <div class="badge ${ENVIRONMENT.toLowerCase()}">
          Entorno: ${ENVIRONMENT}
        </div>
        
        <div class="info-box">
          <p><strong>Versión:</strong> ${VERSION}</p>
          <p><strong>Hostname:</strong> ${os.hostname()}</p>
          <p><strong>Timestamp:</strong> ${new Date().toLocaleString('es-ES')}</p>
          <p><strong>Uptime:</strong> ${Math.floor(process.uptime())}s</p>
        </div>

        <p style="color: #666; margin: 20px 0;">
          ✅ La aplicación está funcionando correctamente en el entorno <strong>${ENVIRONMENT}</strong>
        </p>

        <button class="refresh-btn" onclick="location.reload()">🔄 Actualizar</button>

        <div class="version-info">
          <p>API Status: <a href="/status" style="color: #667eea; text-decoration: none;">Ver detalles técnicos</a></p>
        </div>
      </div>
    </body>
    </html>
  `);
});

// Manejo de errores
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ 
    error: 'Internal Server Error',
    message: err.message 
  });
});

// Iniciar servidor
app.listen(PORT, '0.0.0.0', () => {
  console.log(`
  ╔════════════════════════════════════════════════════╗
  ║         Blue-Green Deployment App Running         ║
  ║                                                    ║
  ║  Entorno: ${ENVIRONMENT.padEnd(30)} ║
  ║  Versión: ${VERSION.padEnd(30)} ║
  ║  Puerto: ${PORT.toString().padEnd(31)} ║
  ║  Hostname: ${os.hostname().padEnd(28)} ║
  ║                                                    ║
  ║  🌐 http://localhost:${PORT}                        ║
  ║  🏥 http://localhost:${PORT}/health                 ║
  ║  📊 http://localhost:${PORT}/status                 ║
  ║                                                    ║
  ╚════════════════════════════════════════════════════╝
  `);
});

// Manejo de terminación graceful
process.on('SIGTERM', () => {
  console.log('SIGTERM recibido. Cerrando gracefully...');
  process.exit(0);
});
