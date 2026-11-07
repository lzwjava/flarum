{
  "debug": false,
  "baseUrl": "${FLARUM_URL}",
  "databaseConfiguration": {
    "driver": "mysql",
    "host": "${DB_HOST}",
    "port": 3306,
    "database": "${DB_DATABASE}",
    "username": "${DB_USERNAME}",
    "password": "${DB_PASSWORD}"
  },
  "adminUser": {
    "username": "${FLARUM_ADMIN_USER}",
    "password": "${FLARUM_ADMIN_PASSWORD}",
    "email": "${FLARUM_ADMIN_EMAIL}"
  },
  "settings": {
    "forum_title": "${FLARUM_FORUM_TITLE}"
  },
  "queue": {
    "driver": "sync"
  }
}
