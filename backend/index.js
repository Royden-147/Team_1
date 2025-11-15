const express = require('express');
const { Pool } = require('pg');

const PORT = process.env.PORT || 3000;
const { DB_HOST = '172.20.0.40', DB_PORT = 5432, DB_USER='appuser', DB_PASS='apppassword', DB_NAME='appdb' } = process.env;

const pool = new Pool({
  host: DB_HOST, port: DB_PORT, user: DB_USER, password: DB_PASS, database: DB_NAME
});

const app = express();
app.get('/health', (req, res) => res.json({ ok: true }));
app.get('/api/ping', async (req, res) => {
  try {
    const r = await pool.query('SELECT 1 as ok');
    res.json({ ok: true, db: r.rows[0] });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.listen(PORT, () => console.log(`Backend listening on ${PORT}`));
