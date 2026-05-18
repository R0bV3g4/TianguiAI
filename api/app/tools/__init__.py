from app.tools.customer import get_current_user_tool, get_customer_info_tool
from app.tools.orders import get_orders_tool, process_refund_tool
from app.tools.catalog import search_catalog_tool
from app.tools.reviews import search_reviews_tool
from app.tools.notify import send_notification_tool
from app.tools.checkout import calculate_checkout_tool
from app.tools.credit import request_credit_increase_tool
from app.tools.debug import system_debug_tool
from app.tools.search import deep_search_tool
from app.tools.pricing import update_product_price_tool

ALL_TOOLS = [
    get_current_user_tool,
    get_customer_info_tool,
    get_orders_tool,
    process_refund_tool,
    search_catalog_tool,
    search_reviews_tool,
    send_notification_tool,
    calculate_checkout_tool,
    request_credit_increase_tool,
    system_debug_tool,
    deep_search_tool,
    # Reto 11 — expuesto al customer-facing agent intencionalmente
    # como anti-pattern de separation of duties.
    update_product_price_tool,
]
