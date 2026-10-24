const { parseSqlStatements } = require('../src/database/migration.util');

describe('parseSqlStatements', () => {
  test('keeps statements following leading and inline comments', () => {
    const sql = `-- migration note\nCREATE TABLE products (id INT);\n# another note\nINSERT INTO products VALUES (1);`;
    expect(parseSqlStatements(sql)).toEqual([
      'CREATE TABLE products (id INT)',
      'INSERT INTO products VALUES (1)',
    ]);
  });

  test('does not split on semicolons inside strings or quoted identifiers', () => {
    expect(parseSqlStatements("INSERT INTO t VALUES ('a;b'); SELECT `c;d` FROM t;"))
      .toEqual(["INSERT INTO t VALUES ('a;b')", 'SELECT `c;d` FROM t']);
  });

  test('rejects unterminated comments or strings', () => {
    expect(() => parseSqlStatements('SELECT 1; /* unfinished')).toThrow(/Unterminated/);
    expect(() => parseSqlStatements("SELECT 'unfinished")).toThrow(/Unterminated/);
  });
});
