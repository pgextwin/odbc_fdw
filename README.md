# odbc_fdw on Windows

This repository builds [CARTO's odbc_fdw](https://github.com/CartoDB/odbc_fdw)
with MSVC for PostgreSQL 15, 16, and 17 on Windows x64. It pins
[PR #143](https://github.com/CartoDB/odbc_fdw/pull/143) at
`dfb157dbf75c41381687608caf8fd35e2f973493`, based on upstream tag
`0.5.2.3` with the PostgreSQL 17 planner change. The version reported by
`CREATE EXTENSION odbc_fdw` is `0.5.2`. PostgreSQL 18 requires an
additional planner argument that this revision does not supply.

The package contains the DLL, control file, install and upgrade SQL, and the
full [PostgreSQL License](LICENSE). The DLL uses the Windows ODBC Driver
Manager. Install a 64-bit ODBC driver for your target database on the
PostgreSQL host. The CI smoke test uses the runner's Microsoft ODBC driver
and SQL Server LocalDB to read rows through a foreign table.

License evidence for the pinned revision is the [upstream LICENSE](https://github.com/CartoDB/odbc_fdw/blob/dfb157dbf75c41381687608caf8fd35e2f973493/LICENSE),
1,126 bytes with SHA-256 `faf8bd06943733f181eb43eed094b3717470c8a6b2fb8c378628e26a7ef2a2c4`
and Git blob `c56e1e8ea8cbce7630eb88f9515b19c4a38b6b7b`.
