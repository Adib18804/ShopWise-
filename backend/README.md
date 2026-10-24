# ShopWise Backend API

Smart Business Assistant for Small Grocery Shopkeepers - Backend REST API

## Tech Stack

- **Runtime:** Node.js 18+
- **Framework:** Express.js
- **Database:** MySQL 8.0+
- **Authentication:** JWT (JSON Web Tokens)
- **Validation:** express-validator
- **Testing:** Jest + Supertest
- **Logging:** Winston
- **Push Notifications:** Firebase Cloud Messaging

## Prerequisites

- Node.js >= 18.0.0
- npm >= 9.0.0
- MySQL >= 8.0
- Firebase project (for push notifications)

## Installation

1. Clone the repository
```bash
git clone <repository-url>
cd backend
```

2. Install dependencies
```bash
npm install
```

3. Configure environment variables
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Create MySQL database
```bash
mysql -u root -p
CREATE DATABASE shopwise_dev;
CREATE USER 'shopwise_user'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON shopwise_dev.* TO 'shopwise_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

5. Run migrations
```bash
npm run migrate
```

6. (Optional) Seed development data
```bash
npm run seed
```

## Running the Server

### Development Mode
```bash
npm run dev
```

### Production Mode
```bash
npm start
```

Server will start on `http://localhost:3000`

## API Documentation

Full API documentation is available in `/API.md`

Base URL: `http://localhost:3000/api/v1`

### Health Check
```bash
curl http://localhost:3000/api/health
```

## Project Structure

```
backend/
├── src/
│   ├── config/           # Configuration files
│   ├── controllers/      # Request handlers
│   ├── middleware/       # Express middleware
│   ├── models/           # Data models
│   ├── repositories/     # Database access layer
│   ├── services/         # Business logic layer
│   ├── routes/           # API routes
│   ├── validators/       # Request validation
│   ├── utils/            # Utility functions
│   ├── analysis/         # Intelligence analysis modules
│   ├── notifications/    # Notification system
│   ├── database/         # Database migrations & seeds
│   ├── app.js            # Express app setup
│   └── server.js         # Server entry point
├── tests/                # Test files
├── logs/                 # Log files (auto-generated)
├── .env.example          # Environment variables template
├── .gitignore
├── package.json
└── README.md
```

## Testing

### Run all tests
```bash
npm test
```

### Run tests in watch mode
```bash
npm run test:watch
```

### Generate coverage report
```bash
npm test -- --coverage
```

## Linting

### Check for linting errors
```bash
npm run lint
```

### Auto-fix linting errors
```bash
npm run lint:fix
```

## Database Migrations

Migrations are located in `src/database/migrations/`

### Run migrations
```bash
npm run migrate
```

### Seed development data
```bash
npm run seed
```

## Environment Variables

See `.env.example` for all required environment variables.

**Critical:** Never commit `.env` file to version control!

## Security

- Passwords are hashed using bcrypt
- JWT tokens for authentication
- Input validation on all endpoints
- SQL injection protection (parameterized queries)
- Rate limiting enabled
- CORS configured
- Helmet.js for HTTP headers security

## API Endpoints

### Authentication
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login
- `GET /api/v1/auth/me` - Get current user
- `POST /api/v1/auth/logout` - Logout

### Shop
- `POST /api/v1/shop` - Create shop
- `GET /api/v1/shop` - Get shop details
- `PUT /api/v1/shop` - Update shop

### Products
- `GET /api/v1/products` - Get all products
- `GET /api/v1/products/:id` - Get product details
- `POST /api/v1/products` - Create product
- `PUT /api/v1/products/:id` - Update product
- `DELETE /api/v1/products/:id` - Delete product

### Stock & Batches
- `POST /api/v1/products/:id/batches` - Add stock batch
- `GET /api/v1/products/:id/batches` - Get product batches
- `PUT /api/v1/batches/:id` - Update batch
- `GET /api/v1/products/:id/stock-history` - Get stock history

### Sales
- `GET /api/v1/sales` - Get sales history
- `GET /api/v1/sales/:id` - Get sale details
- `POST /api/v1/sales` - Record new sale

### Dashboard
- `GET /api/v1/dashboard/summary` - Get dashboard summary

### Analysis
- `GET /api/v1/analysis/expiry-risk` - Get expiry risk analysis
- `GET /api/v1/analysis/stock-risk` - Get stock-out risk
- `GET /api/v1/analysis/restock` - Get restock recommendations
- `GET /api/v1/analysis/slow-moving` - Get slow-moving products
- `GET /api/v1/analysis/fefo` - Get FEFO recommendations
- `GET /api/v1/analysis/profit` - Get profit analysis
- `GET /api/v1/analysis/daily-summary` - Get daily summary

### Notifications
- `GET /api/v1/notifications` - Get notifications
- `PATCH /api/v1/notifications/:id/read` - Mark as read
- `PATCH /api/v1/notifications/read-all` - Mark all as read

## Troubleshooting

### Database connection error
- Check MySQL is running: `mysql -u root -p`
- Verify credentials in `.env`
- Ensure database exists: `SHOW DATABASES;`

### Port already in use
- Change PORT in `.env`
- Or kill process: `lsof -ti:3000 | xargs kill`

### JWT authentication failing
- Check JWT_SECRET in `.env`
- Verify token expiration time
- Check Authorization header format: `Bearer <token>`

## Production Deployment

1. Set `NODE_ENV=production` in `.env`
2. Use strong JWT_SECRET (min 32 characters)
3. Configure production database
4. Set up HTTPS/SSL
5. Configure CORS for production domain
6. Enable proper logging
7. Set up database backups
8. Use process manager (PM2):
```bash
npm install -g pm2
pm2 start src/server.js --name shopwise-api
```

## Support

For issues and questions, please refer to:
- Architecture: `/ARCHITECTURE.md`
- Database: `/DATABASE.md`
- API: `/API.md`
- Business Logic: `/BUSINESS_LOGIC.md`

## License

MIT
