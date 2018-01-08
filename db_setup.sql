-- APPSEC tables 

drop view v_app_user_role;
drop view v_app_route_role;
drop view v_app_user_route_roles;
drop table as_user_role;
drop table as_route_role;
drop table as_user;
drop table as_route;
drop table as_role;
drop table as_profile;
--drop table as_priv;
drop table as_app;
go
/* as_app - One entry per application.  This allows the tables to support mulitple applications, if you so desire
 */
create table as_app (
	app_id			integer identity(1,1) primary key,
	app_name		varchar(100) not null,
	description		varchar(256),
	environment		varchar(30) not null default 'DEV' check ( environment in ( 'DEV', 'TEST', 'PROD' ) ),
	insert_dtm		datetime not null default CURRENT_TIMESTAMP,
	update_dtm		datetime not null default CURRENT_TIMESTAMP
);
go

create unique index uq_as_app_name on as_app(app_name);
go

create trigger tg_as_app_update
ON as_app
AFTER UPDATE
AS
	set nocount on;

    UPDATE dbo.as_app
       SET update_dtm = CURRENT_TIMESTAMP
     WHERE app_id IN (SELECT app_id FROM Inserted);

go

create table as_profile (
	profile_id		integer identity(1,1) primary key,
	app_id			integer not null,
	profile_nm		varchar(50),
	insert_dtm		datetime not null default CURRENT_TIMESTAMP,
	update_dtm		datetime not null default CURRENT_TIMESTAMP
	foreign key(app_id) references as_app(app_id)
);

create unique index uq_as_profile_profile_nm on as_profile(profile_nm);
go

create trigger tg_as_profile
on as_profile
after update
as
	set nocount on;

	update as_profile 
	   set update_dtm = CURRENT_TIMESTAMP
	 where profile_id in ( select profile_id from inserted );
go

/* as_user - One entry per username, enforced.
 */
create table as_user (
	user_id			integer identity(1,1) primary key,
	app_id			integer not null,
	username		varchar(100) not null,
	profile_id		integer,
	insert_dtm		datetime not null default CURRENT_TIMESTAMP,
	update_dtm		datetime not null default CURRENT_TIMESTAMP
	foreign key(app_id) REFERENCES as_app(app_id),
	foreign key(profile_id) references as_profile(profile_id)
);
go

create unique index uq_ap_user_username on as_user( username );
go

create trigger tg_as_user_update
on as_user
after update
as 
	set nocount on;

	update as_user
	   set update_dtm = CURRENT_TIMESTAMP
	 where user_id in ( select user_id from INSERTED );
go
/* as_route - list of routes.  Route + method + app is unique.
 */
create table as_route (
	route_id		integer identity(1,1) primary key,
	app_id			integer not null,
	route_nm		varchar(100) not null,
	method			varchar(40) not null default 'GET' check ( method in ( 'GET', 'POST', 'PUT', 'HEAD', 'DELETE', 'CONNECT', 'OPTIONS', 'TRACE', 'PATCH' ) ), 
	route			varchar(800) not null,
	description		varchar(256),
	insert_dtm		datetime not null default CURRENT_TIMESTAMP,
	update_dtm		datetime not null default CURRENT_TIMESTAMP
	foreign key(app_id) REFERENCES as_app(app_id)
);
go

create unique index uq_as_route_route on as_route( app_id, method, route );
go

create trigger tg_as_route
on as_route 
after update
as
	set nocount on;

	update as_route
	   set update_dtm = CURRENT_TIMESTAMP
	 where route_id in ( select route_id from inserted );
go

/* as_role - list of roles, app_id + role_nm is unique 
 */
create table as_role (
	role_id			integer identity(1,1) primary key,
	app_id			integer not null,
	role_nm			varchar(100) not null,
	insert_dtm		datetime not null default CURRENT_TIMESTAMP,
	update_dtm		datetime not null default CURRENT_TIMESTAMP
	foreign key(app_id) REFERENCES as_app(app_id)
);

create unique index uq_as_role_approle on as_role(app_id, role_nm);
go

create trigger tg_as_role
on as_role
after update 
as
	set nocount on;

	update as_role
	   set update_dtm = CURRENT_TIMESTAMP
	 where role_id in ( select role_id from inserted );
go
/* as_user_role - assign a user to a role, multile assignments possible
 */
create table as_user_role (
	app_id			integer not null,
	user_id			integer not null,
	role_id			integer not null
	primary key( app_id, user_id, role_id )
	foreign key(app_id) references as_app(app_id),
	foreign key(role_id) references as_role(role_id),
	foreign key(user_id) references as_user(user_id)
);
go

/* as_route_role - assign a role requirement to a route_id (route+method)
 */
create table as_route_role (
	app_id			integer not null,
	role_id			integer not null,
	route_id		integer not null
	primary key( app_id, role_id, route_id )
	foreign key(app_id) references as_app(app_id),
	foreign key(role_id) references as_role(role_id),
	foreign key(route_id) references as_route(route_id)
);
go

/* Privs could be returned as an object with properties at some time in the future. . . not today.
create table as_priv (
	priv_id			integer identity(1,1) primary key,
	app_id			integer not null,
	priv_nm			varchar(100) not null,
	property		varchar(100) not null,
	value			varchar(100) not null,
	description		varchar(100),

	foreign key(app_id) references as_app(app_id)
);
go

create unique index uq_as_priv_apppriv on as_priv( app_id, priv_nm );
go
*/

-- Show values for the user/role link table
create view v_app_user_role
as
select a.app_id,
       a.app_name,
	   a.environment,
	   a.description,
	   u.user_id,
	   u.username,
	   r.role_id,
	   r.role_nm
  from as_app a
  join as_user_role ur on ( ur.app_id = a.app_id )
  join as_user u on ( u.app_id = ur.app_id and u.user_id = ur.user_id )
  join as_role r on ( u.app_id = ur.app_id and r.role_id = ur.role_id )
go

-- Show values for the route/role link table
create view v_app_route_role 
as
select a.app_id,
	   a.app_name,
	   a.environment,
	   ro.method,
	   ro.route_id,
	   ro.route_nm,
	   rl.role_id,
	   rl.role_nm
  from as_app a
  join as_route_role rr on ( rr.app_id = a.app_id )
  join as_route ro on ( ro.app_id = rr.app_id and ro.route_id = rr.route_id )
  join as_role rl on ( rl.app_id = rr.app_id and rl.role_id = rr.role_id );

go

-- Show a complete set of user/route/roles for any app, user, route (add predicate to refine, i.e. select * from v_app_user_route_roles where app_id = 1)

create view v_app_user_route_roles
as
select a.app_name,
	   u.username,
	   r.route_nm,
	   r.method,
	   r.route,
	   role.role_nm
  from as_app a
  join as_user_role ur on ( ur.app_id = a.app_id )
  join as_route_role rr on ( rr.app_id = a.app_id )
  join as_user u on ( u.app_id = ur.app_id and u.user_id = ur.user_id )
  join as_route r on ( r.app_id = rr.app_id and r.route_id = rr.route_id )   
  join as_role role on ( role.app_id = a.app_id and role.role_id = ur.role_id and role.role_id = rr.role_id );

go

-- EXAMPLE DATA BELOW,  This needs some sort of default user/role mechanism.

insert into as_app( app_name, description, environment ) values ( 'TESTAPP', 'THIS IS A DUMMY APP FOR TESTING', 'DEV' );

insert into as_user( app_id, username ) values ( 1, '*' );
insert into as_user( app_id, username ) values ( 1, 'Don' );
insert into as_user( app_id, username ) values ( 1, 'Frank' );

insert into as_role( app_id, role_nm ) values ( 1, 'SYSADMIN' );
insert into as_role( app_id, role_nm ) values ( 1, 'ADMIN' );
insert into as_role( app_id, role_nm ) values ( 1, 'READONLY' );
insert into as_role( app_id, role_nm ) values ( 1, 'UPDATE' );
insert into as_role( app_id, role_nm ) values ( 1, 'INSERT' );
insert into as_role( app_id, role_nm ) values ( 1, 'DELETE' );

insert into as_route( app_id, route_nm, method, route, description ) values ( 1, 'Home', 'GET', '/home', 'Home page' );
insert into as_route( app_id, route_nm, method, route, description ) values ( 1, 'Login', 'GET', '/login', 'Get to a login page' );
insert into as_route( app_id, route_nm, method, route, description ) values ( 1, 'Login', 'POST', '/login', 'Login attempt' );

--insert into as_priv( app_id, priv_nm, property, value, description ) values ( 1, 'Insert', 'INSERT', 'Y', 'Insert new rows' );

-- ANYONE can get/post to login page
insert into as_user_role( app_id, user_id, role_id ) values ( 1, 1, 2 );
insert into as_user_role( app_id, user_id, role_id ) values ( 1, 1, 3 );

-- Don has GET access to /home
insert into as_user_role( app_id, user_id, role_id ) values ( 1, 2, 1 );
insert into as_route_role( app_id, route_id, role_id ) values ( 1, 1, 1 );

-- Frank has GET access to the /login route
insert into as_user_role( app_id, user_id, role_id ) values ( 1, 2, 3 );
insert into as_route_role( app_id, route_id, role_id ) values ( 1, 2, 3 );

-- add Frank to SYSADMIN
insert into as_user_role ( app_id, user_id, role_id ) values ( 1, 3, 1 );

select * from as_app
select * from as_user
select * from as_role
select * from as_route
-- select * from as_priv
select * from as_user_role
select * from as_route_role
select * from v_app_user_role
select * from v_app_route_role
select * from v_app_user_route_roles

