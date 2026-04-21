from pathlib import Path

from supabase_config import get_supabase_client


def main() -> None:
    supabase = get_supabase_client()
    sql_path = Path(__file__).resolve().parent / 'create_favorites_tables.sql'
    sql = sql_path.read_text(encoding='utf-8')

    candidates = [
        ('exec_sql', {'sql': sql}),
        ('execute_sql', {'sql': sql}),
        ('run_sql', {'sql': sql}),
        ('sql', {'query': sql}),
        ('query', {'sql': sql}),
    ]

    for name, payload in candidates:
        try:
            result = supabase.rpc(name, payload).execute()
            print(f'RPC_OK {name} data_type={type(result.data).__name__}')
            return
        except Exception as exc:
            print(f'RPC_FAIL {name} {str(exc)[:220]}')

    print('NO_SUPPORTED_RPC_FOR_SQL_EXEC')


if __name__ == '__main__':
    main()
