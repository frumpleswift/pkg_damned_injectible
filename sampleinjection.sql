--drop table vehicles;

--create table vehicles(make varchar2(300) not null, model varchar2(300) not null, year varchar2(4) not null);




create or replace package pkg_damned_injectible 
as

procedure print_api;

--remake the bad dbms_assert.enquote_literal
--function enquote_literal(p_string in varchar2) return varchar2;

--typical SQLi in select statement
procedure boring_select(p_make in varchar2
	               ,p_model in varchar2
		       ,p_year in varchar2
	              ,p_difficulty IN NUMBER DEFAULT 3);

--insert statement
procedure inject_insert(p_make IN varchar2
		      ,p_model IN varchar2
	              ,p_year in varchar2
	              ,p_difficulty IN NUMBER DEFAULT 3);

--in the select list
procedure in_select_list(p_make IN varchar2
			,p_difficulty IN number default 3);	

--using "q" quoting
-- v_sql:= q'~Select * from all_tables where owner='bob'~'
procedure q_quote_select(p_make in varchar2
			,p_model in varchar2
			,p_year in varchar2
	              ,p_difficulty IN NUMBER DEFAULT 3);

--breaking old dbms_assert
procedure bad_dbms_assert_select(p_make in varchar2
				,p_model in varchar2
				,p_year in varchar2
	              ,p_difficulty IN NUMBER DEFAULT 3);

--multi-parameter sqli
procedure multi_parm_sql(p_make in varchar2
	                ,p_model in varchar2
			,p_year in varchar2
	              ,p_difficulty IN NUMBER DEFAULT 3);

-- stored sqli

--numeric_injection

procedure numeric_injection(p_make in varchar2
	                ,p_year_start in varchar2
			,p_year_end in varchar2
	              ,p_difficulty IN NUMBER DEFAULT 3);

end pkg_damned_injectible;
/

create or replace package body pkg_damned_injectible
as

g_sql varchar2(4000);
--g_cursor sys_refcursor;
g_xml xmltype;

procedure check_whitelist(p_parm in varchar2)
is

BEGIN

	if regexp_like(p_parm,'^[a-zA-Z0-9._() ,]*$') then
		--pass
		null;
	else
		raise_application_error(-20666,'Invalid character encountered');
	end if;
END check_whitelist;

procedure print_api
is

begin
	htp.p('
PKG_DAMNED_INJECTIBLE:

	All of the following procedures take in a helper parameter called p_difficulty (default 3) which can add extra error information to the output
		p_difficulty=3 returns:
		<ERROR>An Error has Occured with your request</ERROR>

		p_difficulty=2 returns the SQL Error Message:
		<ERROR>ORA-00911: invalid character</ERROR>

		p_difficulty=1 returns the SQL Error message and query:
		<ERROR>ORA-00911: invalid character</ERROR>
		<QUERY>SELECT make,model,year from vehicles where make like ''%HONDA%'' and model like ''%ODYSSEY%'' and year like ''%2%''</QUERY>

	IN_SELECT_LIST:
		Sample CURL:
		curl -X POST http://localhost:8080/pls/public/pkg_damned_injectible.in_select_list -d "p_make=HONDA"
		Sample Output:
		<CATALOG><HONDA><MODEL>ODYSSEY</MODEL><YEAR>2008</YEAR></HONDA><HONDA><MODEL>ODYSSEY</MODEL><YEAR>2009</YEAR></HONDA><HONDA><MODEL>ODYSSEY</MODEL><YEAR>2010</YEAR></HONDA></CATALOG>
	BORING_SELECT:
		Sample CURL:
			curl -X POST http://localhost:8080/pls/public/pkg_damned_injectible.boring_select -d "p_make=HONDA&p_model=ODYSSEY&p_year=2"
		Sample Output:
			<?xml version="1.0"?>
			<ROWSET>
			 <ROW>
			  <MAKE>HONDA</MAKE>
			  <MODEL>ODYSSEY</MODEL>
			  <YEAR>2008</YEAR>
			 </ROW>
			 <ROW>
			  <MAKE>HONDA</MAKE>
			  <MODEL>ODYSSEY</MODEL>
			  <YEAR>2009</YEAR>
			 </ROW>
			 <ROW>
			  <MAKE>HONDA</MAKE>
			  <MODEL>ODYSSEY</MODEL>
			  <YEAR>2010</YEAR>
			 </ROW>
			</ROWSET>
INJECT_INSERT:
		Sample CURL:
		curl -X POST http://localhost:8080/pls/public/pkg_damned_injectible.inject_insert -d "p_make=HONDA&p_model=INSIGHT&p_year=2011"
		Sample Output:
		<ROWS>1</ROWS
	Q_QUOTE_SELECT:
		Sample Curl:
		curl -X POST http://localhost:8080/pls/public/pkg_damned_injectible.q_quote_select -d "p_make=AUDI&p_model=A4&p_year=2"
		Sample Output:
		<?xml version="1.0"?>
		<ROWSET>
		 <ROW>
		  <MAKE>AUDI</MAKE>
		  <MODEL>A4</MODEL>
		  <YEAR>2010</YEAR>
		 </ROW>
		</ROWSET>
	BAD_DBMS_ASSERT_SELECT:
		Sample curl:
		curl -X POST http://localhost:8080/pls/public/pkg_damned_injectible.bad_dbms_assert_select -d "p_make=AUDI&p_model=XXX&p_year=XXXX"
		Sample Output:
		<?xml version="1.0"?>
		<ROWSET>
		 <ROW>
		  <MAKE>AUDI</MAKE>
		  <MODEL>A4</MODEL>
		  <YEAR>2010</YEAR>
		 </ROW>
		</ROWSET>
		');
END print_api;

procedure handle_error(p_errm IN VARCHAR2
	              ,p_difficulty IN NUMBER DEFAULT 3)
as

begin
	case p_difficulty
		when 3 then 
			htp.p('<ERROR>An Error has Occured with your request</ERROR>');
		when 2 then
			htp.p('<ERROR>'|| p_ERRM || '</ERROR>');
		when 1 then	
			htp.p('<ERROR>'|| p_ERRM || '</ERROR>');
			htp.p('<QUERY>'||g_sql||'</QUERY>');
		else
			htp.p('<ERROR/>');
	end case;
end handle_error;

procedure  htp_prn_clob(p_clob in clob)
is
	l_offset number default 1;
begin
     loop
       exit when l_offset > dbms_lob.getlength(p_clob);
       htp.p( dbms_lob.substr( p_clob, 255, l_offset ) );
       l_offset := l_offset + 255;
     end loop;
end htp_prn_clob;

function quote_parm(p_parm in varchar2) return varchar2
is

begin

	return 'q''{' || p_parm || '}''';

end;	

--remake the bad dbms_assert.enquote_literal
function enquote_literal(p_string in varchar2) return varchar2
is

begin
	if p_string = '''' then 
		return p_string;
	else
		return dbms_assert.enquote_literal(p_string);
	end if;
end enquote_literal;

--typical SQLi in select statement
procedure boring_select(p_make in varchar2
	               ,p_model in varchar2
		       ,p_year in varchar2
	              ,p_difficulty IN NUMBER DEFAULT 3)
is
 
	l_cursor sys_refcursor;

begin
	g_sql := 'SELECT make,model,year from vehicles where make like ''%'||p_make||'%'' and model like ''%'||p_model||'%'' and year like ''%'||p_year||'%''';

	open l_cursor for g_sql;

	g_xml := xmltype.createxml(l_cursor);

	close l_cursor;

	htp_prn_clob(g_xml.getclobval);

exception
when others then
	handle_error(sqlerrm,p_difficulty);
end boring_select;
--insert statement
procedure inject_insert(p_make IN varchar2
		      ,p_model IN varchar2
	              ,p_year in varchar2
	              ,p_difficulty IN NUMBER DEFAULT 3)
is
begin
	g_sql := 'insert into vehicles values (''' || p_make || ''','''|| p_model || ''',''' || p_year || ''')';

	execute immediate g_sql;

	htp.p('<ROWS>' || sql%rowcount || '</ROWS');

	commit;

exception
when others then
	handle_error(sqlerrm,p_difficulty);
end inject_insert;

--in the select list
procedure in_select_list(p_make IN varchar2
                        ,p_difficulty in number default 3)
is

	l_cursor sys_refcursor;

begin
	
	g_sql := 'select xmlelement("CATALOG",xmlagg(xmlelement("'||p_make||'",xmlforest(model,year)))) from vehicles where make = :1';

	execute immediate g_sql into g_xml using p_make;

	htp_prn_clob(g_xml.getclobval);

exception
when others then
	handle_error(sqlerrm,p_difficulty);
end in_select_list;

--using "q" quoting
-- v_sql:= q'~Select * from all_tables where owner='bob'~'
procedure q_quote_select(p_make in varchar2
			,p_model in varchar2
			,p_year in varchar2
	              ,p_difficulty IN NUMBER DEFAULT 3)
is

	v_make varchar2(200) := quote_parm(p_make);
	v_model varchar2(200) := quote_parm(p_model);
	v_year varchar2(200) := quote_parm(p_year);

	l_cursor sys_refcursor;

begin
	g_sql := 'SELECT make,model,year from vehicles where make='||v_make||' or model='||v_model||' or year='||v_year;

	open l_cursor for g_sql;

	g_xml := xmltype.createxml(l_cursor);

	close l_cursor;

	htp_prn_clob(g_xml.getclobval);

exception
when others then
	handle_error(sqlerrm,p_difficulty);
end q_quote_select;

--breaking old dbms_assert
procedure bad_dbms_assert_select(p_make in varchar2
				,p_model in varchar2
				,p_year in varchar2
	              ,p_difficulty IN NUMBER DEFAULT 3)
is

	l_cursor sys_refcursor;

begin
	g_sql := 'SELECT make,model,year from vehicles where make ='||enquote_literal(p_make)||' or model ='||enquote_literal(p_model)||' or year='||enquote_literal(p_year); 

	open l_cursor for g_sql;

	g_xml := xmltype.createxml(l_cursor);

	close l_cursor;

	htp_prn_clob(g_xml.getclobval);
exception
when others then
	handle_error(sqlerrm,p_difficulty);
end bad_dbms_assert_select;

--multi-parameter sqli
procedure multi_parm_sql(p_make in varchar2
	                ,p_model in varchar2
			,p_year in varchar2
	              ,p_difficulty IN NUMBER DEFAULT 3)
is

	v_make varchar2(10) := p_make;
	v_model varchar2(10) := p_model;
	v_year varchar2(4) := p_year;

	l_cursor sys_refcursor;
begin
	g_sql := 'SELECT make,model,year from vehicles where make like ''%'||v_make||'%'' and model like ''%'||v_model||'%'' and year like ''%'||v_year||'%''';

	open l_cursor for g_sql;

	g_xml := xmltype.createxml(l_cursor);

	close l_cursor;


	htp_prn_clob(g_xml.getclobval);
exception
when others then
	handle_error(sqlerrm,p_difficulty);
end multi_parm_sql;

procedure numeric_injection(p_make in varchar2
	                ,p_year_start in varchar2
			,p_year_end in varchar2
	              ,p_difficulty IN NUMBER DEFAULT 3)
IS

	l_cursor sys_refcursor;

BEGIN

	check_whitelist(p_make);
	check_whitelist(p_year_start);
	check_whitelist(p_year_end);

	g_sql := 'SELECT make, model,year from vehicles where make like ''%'||p_make||'%'' and year between ' || p_year_start || ' and ' || p_year_end;

	open l_cursor for g_sql;

	g_xml := xmltype.createxml(l_cursor);

	close l_cursor;

	htp_prn_clob(g_xml.getclobval);

exception
when others then
	handle_error(sqlerrm,p_difficulty);
end numeric_injection;

end pkg_damned_injectible;
/

