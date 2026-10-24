/**
 * Split ordinary MySQL migration scripts into statements while ignoring SQL
 * comments and semicolons inside quoted strings/identifiers.
 */
function parseSqlStatements(sql) {
  const statements = [];
  let statement = '';
  let quote = null;
  let lineComment = false;
  let blockComment = false;

  for (let i = 0; i < sql.length; i += 1) {
    const char = sql[i];
    const next = sql[i + 1];

    if (lineComment) {
      if (char === '\n') {
        lineComment = false;
        statement += '\n';
      }
      continue;
    }

    if (blockComment) {
      if (char === '*' && next === '/') {
        blockComment = false;
        i += 1;
      }
      continue;
    }

    if (quote) {
      statement += char;
      if (char === '\\' && quote !== '`' && next) {
        statement += next;
        i += 1;
      } else if (char === quote) {
        if (next === quote) {
          statement += next;
          i += 1;
        } else {
          quote = null;
        }
      }
      continue;
    }

    if (char === '-' && next === '-' && (!sql[i + 2] || /\s/.test(sql[i + 2]))) {
      lineComment = true;
      i += 1;
      continue;
    }
    if (char === '#') {
      lineComment = true;
      continue;
    }
    if (char === '/' && next === '*') {
      blockComment = true;
      i += 1;
      continue;
    }
    if (char === "'" || char === '"' || char === '`') {
      quote = char;
      statement += char;
      continue;
    }
    if (char === ';') {
      if (statement.trim()) statements.push(statement.trim());
      statement = '';
      continue;
    }
    statement += char;
  }

  if (quote || blockComment) throw new Error('Unterminated SQL string or comment');
  if (statement.trim()) statements.push(statement.trim());
  return statements;
}

module.exports = { parseSqlStatements };
