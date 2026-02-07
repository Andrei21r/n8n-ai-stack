# n8n AI Stack Installer

Automated installer for a production-ready n8n stack with AI capabilities, database management, and auto-updates.

## Features

- **n8n (Queue Mode)**: Scalable workflow automation with a separate worker node.
- **AI Ready**: Pre-configured with Ollama for local LLMs.
- **Production Grade**:
  - **PostgreSQL**: Robust database backend.
  - **Redis**: For job queuing and caching.
  - **RabbitMQ**: Message broker for advanced workflows.
- **Secure**:
  - **Caddy**: Automatic HTTPS/SSL certificates (Let's Encrypt).
  - **Auto-Updates**: Watchtower (containers) + Unattended Upgrades (OS).
  - **Backups**: Automated daily backups of the Postgres database.
- **Self-Maintained**:
  - Automatic data pruning (cleanup) to prevent disk overflow.
  - Binary data stored on filesystem, not in DB.
  - Automatic restart on failure or reboot.

## Installation

### Prerequisites
- A server running Ubuntu or Debian (recommended).
- A domain name pointed to your server's IP address (A record).

### Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Andrei21r/n8n-ai-stack.git
   cd n8n-ai-stack
   ```

2. **Run the installer**:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. **Follow the prompts**:
   - Enter your domain name (e.g., `n8n.example.com`).
   - Enter your email (for SSL notifications).

The installer will:
- Check for Docker and install it automatically if missing (Ubuntu/Debian).
- Generate secure random passwords.
- Configure auto-updates.
- Start all services.

## Services & Ports

| Service | Internal Port | External Access |
|---------|---------------|-----------------|
| n8n | 5678 | `https://your-domain.com` |
| RabbitMQ UI | 15672 | `http://your-server-ip:15672` |
| Postgres | 5432 | Internal only |
| Redis | 6379 | Internal only |
| Ollama | 11434 | Internal only |

## Maintenance

- **Logs**: View logs for all services:
  ```bash
  docker compose logs -f
  ```
- **Update**: Services update automatically every 24h via Watchtower. To force update manually:
  ```bash
  docker compose pull && docker compose up -d
  ```
- **Backups**: Database backups are stored in the `./backups` directory on the host.

## License

MIT
