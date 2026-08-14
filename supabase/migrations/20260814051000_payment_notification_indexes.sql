-- Incremental indexes for payment and notification foreign-key access paths.
create index if not exists notification_events_order_id_idx
  on public.notification_events(order_id);
create index if not exists notification_events_sender_id_idx
  on public.notification_events(sender_id);
create index if not exists order_payments_verified_by_idx
  on public.order_payments(verified_by);
create index if not exists order_payments_collected_by_idx
  on public.order_payments(collected_by);
create index if not exists order_payments_refund_completed_by_idx
  on public.order_payments(refund_completed_by);
