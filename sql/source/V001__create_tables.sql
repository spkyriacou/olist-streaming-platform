CREATE SCHEMA IF NOT EXISTS source;

CREATE TABLE IF NOT EXISTS source.customers (
    customer_id                 text PRIMARY KEY,
    customer_unique_id          text,
    customer_zip_code_prefix    text,
    customer_city               text,
    customer_state              text
);

CREATE TABLE IF NOT EXISTS source.geolocation (
    geolocation_id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    geolocation_zip_code_prefix  text,
    geolocation_lat              double precision,
    geolocation_lng              double precision,
    geolocation_city             text,
    geolocation_state            text
);

CREATE TABLE IF NOT EXISTS source.orders (
    order_id                       text PRIMARY KEY,
    customer_id                    text,
    order_status                   text,
    order_purchase_timestamp       timestamp,
    order_approved_at              timestamp,
    order_delivered_carrier_date   timestamp,
    order_delivered_customer_date  timestamp,
    order_estimated_delivery_date  timestamp
);

CREATE TABLE IF NOT EXISTS source.order_items (
    order_id             text,
    order_item_id        integer,
    product_id           text,
    seller_id            text,
    shipping_limit_date  timestamp,
    price                numeric(12, 2),
    freight_value        numeric(12, 2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE IF NOT EXISTS source.order_payments (
    order_id              text,
    payment_sequential    integer,
    payment_type          text,
    payment_installments  integer,
    payment_value         numeric(12, 2),
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE IF NOT EXISTS source.order_reviews (
    review_row_id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    review_id                text,
    order_id                 text,
    review_score             integer,
    review_comment_title     text,
    review_comment_message   text,
    review_creation_date     timestamp,
    review_answer_timestamp  timestamp
);

CREATE TABLE IF NOT EXISTS source.products (
    product_id                  text PRIMARY KEY,
    product_category_name       text,
    product_name_lenght          integer,
    product_description_lenght   integer,
    product_photos_qty          integer,
    product_weight_g            integer,
    product_length_cm           integer,
    product_height_cm           integer,
    product_width_cm            integer
);

CREATE TABLE IF NOT EXISTS source.sellers (
    seller_id               text PRIMARY KEY,
    seller_zip_code_prefix  text,
    seller_city             text,
    seller_state            text
);

CREATE TABLE IF NOT EXISTS source.product_category_translation (
    product_category_name          text PRIMARY KEY,
    product_category_name_english  text
);