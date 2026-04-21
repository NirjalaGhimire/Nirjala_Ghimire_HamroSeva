import React from 'react';

type Col<T> = {
  key: string;
  header: string;
  render?: (row: T) => React.ReactNode;
};

export function DataTable<T extends Record<string, unknown>>({
  columns,
  rows,
  rowKey,
  empty,
}: {
  columns: Col<T>[];
  rows: T[];
  rowKey: (row: T) => string | number;
  empty?: string;
}) {
  if (!rows.length) {
    return <p className="hs-muted">{empty ?? 'No records.'}</p>;
  }
  return (
    <div style={{ overflowX: 'auto' }}>
      <table>
        <thead>
          <tr>
            {columns.map((c) => (
              <th key={c.key}>{c.header}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={rowKey(row)}>
              {columns.map((c) => (
                <td key={c.key}>
                  {c.render ? c.render(row) : String(row[c.key] ?? '—')}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
