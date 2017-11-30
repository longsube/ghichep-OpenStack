# Tập hợp các bug trong quá trình cài đặt và vận hành

## 1.Fix bug gnocchi-metricd lỗi khi nhận metric rỗng (NoneType)
(http://pastebin.com/ANxGzgGK)

```
vim /usr/local/lib/python2.7/dist-packages/gnocchi/storage/_carbonara.py
def _store_timeserie_split(self, metric, key, split,
                               aggregation, archive_policy_def,
                               oldest_mutable_timestamp):
     if split is None:
            offset = 0
            data = '0'
        else:
            offset, data = split.serialize(key, compressed=write_full)
```

## 2.Fix bug Ceilometer không xuất các thông tin về CPU, memory
(Do thiếu trường `disable_non_metric_meters`)

```
vim /etc/ceilometer/ceilometer.conf
...
[notification]
disable_non_metric_meters = false
```