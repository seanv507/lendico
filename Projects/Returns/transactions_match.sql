select 
  replace(reference_text,to_char(lr.loan_request_nr,'FM999999999'),'YYYYYY') as mat from 
  (select virtual_transaction.dwh_country_id,fk_virtual_account, user_id, reference_text, count(*) as c from backend_accounting.virtual_transaction   
  join backend_accounting.virtual_account on (
        virtual_transaction.fk_virtual_account=virtual_account.id_virtual_account
        and 
        virtual_transaction.dwh_country_id=virtual_account.dwh_country_id
        )
  
        where virtual_transaction.dwh_country_id=1 group by virtual_transaction.dwh_country_id, user_id,fk_virtual_account,reference_text ) a
  
  join base.loan_request lr 
        on (a.dwh_country_id=lr.dwh_country_id and a.user_id=lr.fk_user and a.reference_text like '%'||lr.loan_request_nr||'%')

group by mat

