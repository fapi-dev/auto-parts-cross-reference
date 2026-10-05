-- FAPI cross-reference base: the three tables of the SQL archive.
-- One file for MySQL, MariaDB and PostgreSQL.

CREATE TABLE manufacturer_list (
    i integer NOT NULL,
    ds character varying(255) NOT NULL,
    da character varying(255) NOT NULL
);

CREATE TABLE product_list (
    i bigint NOT NULL,
    mfi integer NOT NULL,
    ns character varying(105) NOT NULL,
    n character varying(255),
    d character varying(255),
    tp integer NOT NULL,
    upd bigint DEFAULT 0 NOT NULL
);

CREATE TABLE analog_list (
    i bigint NOT NULL,
    mfi integer NOT NULL,
    ns character varying(105) NOT NULL,
    pi bigint NOT NULL,
    pai bigint NOT NULL,
    r integer NOT NULL
);

ALTER TABLE manufacturer_list ADD CONSTRAINT pk_manufacturer_list_i PRIMARY KEY (i);
ALTER TABLE product_list ADD CONSTRAINT pk_product_list_i PRIMARY KEY (i);
ALTER TABLE analog_list ADD CONSTRAINT pk_analog_list_i PRIMARY KEY (i);

CREATE INDEX k_manufacturer_list_da ON manufacturer_list (da);
CREATE INDEX k_product_list_ns ON product_list (ns);
CREATE INDEX k_analog_list_ns ON analog_list (ns);
CREATE INDEX k_analog_list_pai ON analog_list (pai);
