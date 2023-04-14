-- Active: 1680598839807@@127.0.0.1@3306@sample
create table numbers (
  id INT PRIMARY KEY AUTO_INCREMENT,
  value INT NOT NULL
);

insert into numbers (value) values (30), (10), (40);

select * from numbers;

update numbers
set value = (
  with recursive serial as (
    select 1 as value
    union all
    select value + 1
    from serial
    where value < 10000000
  )
  select max(value) from serial
)
where id = 1
;

set cte_max_recursion_depth = 10000000;

-- デッドロックが起こらなかった、よくわからない例

-- T1
begin;
select * from numbers where id = 1 for share;

-- T2
begin;
select * from numbers where id = 1 for update;

-- T1
select * from numbers where id = 1 for update;

-- デッドロックが起こる例

-- T1
begin;
select * from numbers where id = 1 for update;

-- T2
begin;
select * from numbers where id = 2 for update;

-- T1
select * from numbers where id = 2 for update;

-- T2
select * from numbers where id = 1 for update;

-- デッドロックが起こりそうな例2

-- T1
begin;
select * from numbers where id = 1 for share;

--T2
begin;
select * from numbers where id = 1 for share;

-- T1（T2の共有ロックの解除待ちになる）
update numbers set value = 100 where id = 1;

-- T2（デッドロック）
update numbers set value = 100 where id = 1;

-- 商品
create table products (
  id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(191) NOT NULL
);

-- 在庫
create table inventories (
  id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  product_id INT NOT NULL,
  current_quantity INT NOT NULL,

  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 入荷
create table arrivals (
  id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  inventory_id INT NOT NULL,
  quantity INT NOT NULL,
  arrived_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (inventory_id) REFERENCES inventories(id) ON DELETE RESTRICT ON UPDATE CASCADE
);

insert into products (id, name) values (1, 'ハサミ'), (2, 'ノート'), (3, 'ボールペン');
insert into inventories (product_id, current_quantity) values (1, 10), (2, 30);

-- 入荷でデッドロックが発生しそうな例

-- T1: 在庫の共有ロックを取得する
begin;
insert into arrivals (inventory_id, quantity) values (1, 10);

-- T2: 在庫の共有ロックを取得する
begin;
insert into arrivals (inventory_id, quantity) values (1, 20);

-- T1: 在庫の排他ロックを取得しようとする（共有ロックの解放待ち）
update inventories set current_quantity = current_quantity + 10 where id = 1;

-- T2: 在庫の排他ロックを取得しようとする（→デッドロック）
update inventories set current_quantity = current_quantity + 20 where id = 1;

-- これは、最初に排他ロックを取得しておくことで対策できる
select id from inventories where id = 1 for update;
