# Ceilometer Transformer

## 1. Giới thiệu

Transformer là một phần trong Ceilometer pipeline, là cơ chế xử lý sample thu thập. Trong Ceilometer có các pipeline cho samples và events.
Transformer chịu trách nhiệm biến đổi các datapoint và chuyển chúng tới các Publisher trước khi gửi ra các hệ thống bên ngoài.
Có các lọai transformer như sau:


```
| STT | Loại Transformer | Mô tả                                                               |
|-----|------------------|---------------------------------------------------------------------|
| 1   | Accumulator      | Tập hợp giá trị của nhiều sample và gửi đi 1 lần                    |
| 2   | Aggregator       | Cộng dồn nhiều sample thành một                                     |
| 3   | Arithmetic       | Tính toán sample theo tỉ lệ %                                       |
| 4   | Rate of change   | Thể hiện sự thay đổi giá trị của sample qua từng giây               |
| 5   | Unit conversion  | Đặt đơn vị cho sample                                               |
| 6   | Delta            | Thể hiện sự thay đổi giá trị giữa 2 sample datapoint của 1 resource |                                                                              
```
Việc sử dụng transformer được cấu hình trong file `/etc/ceilometer/pipeline.yaml`
Các thông tin ceilometer notification agent lấy từ Notification bus và từ Ceilometer-collector được gọi là `sample`, các thông tin sau khi đã qua transformer, chuẩn bị được publish gọi là `meter`.
Ngoài ra, ceilometer sử dụng các type sau cho meter:
```
| STT | Type       | Mô tả                                                                            |
|-----|------------|----------------------------------------------------------------------------------|
| 1   | Cumulative | thể hiện giá trị tăng dần. VD: disk.bytes                                        |
| 2   | Delta      | thể hiện chênh lệch giá trị giữa 2 datapoint liên tiếp của sample. VD: cpu.delta |
| 3   | Gauge      | thể hiện giá trị cụ thể tại một thời điểm. VD: disk.bytes.rate                   |
```


## 2. Transformers
### 2.1. Accumulator
Loại transformer này cache các sample và khi đạt tới ngưỡng sẽ đẩy tất cả vào pipeline 1 lần
VD:
```
sources:
    - name: meter_source
      interval: 60
      meters:
          - "*"
      sinks:
          - meter_sink
sinks:
    - name: meter_sink
	  transformers:
          - name: "accumulator"
            parameters:
                size: 15
      publishers:
          - notifier://
```

Với cấu hình trên, các sample sẽ được gom lại vào cache, khi đủ 15 sample thì transformer này sẽ đẩy tất cả vào pipeline.

### 2.2. Aggregator
Transformer này sẽ cộng dồn giá trị các sample cho tới khi đạt ngưỡng số lượng sample hoặc đạt ngưỡng timeout.
Số lượng sample có thể được set bởi option `size`, trong khi đó timeout được set với option `retention_time`.
Các sample được cộng dựa theo các thuộc tính `project_id`, `user_id`, `resource_metadata`. Để cộng các sample theo thuộc tính, ta đặt các thuộc tính đó vào trong file cấu hình pipeline.yaml như sau:
```
sources:
	- name: cpu_source
      interval: 60
      meters:
          - "cpu"
      sinks:
          - cpu_aggregator
sinks:
 	- name: cpu_aggregator
      transformers:
          - name: "aggregator"
            parameters:
              target:
                name: "cpu_aggregator"
                retention_time: 60
                user_id: first
                resource_metadata: last
      publishers:
          - notifier://

```

Với cấu hình trên, ta sẽ cộng dồn các giá trị của sample `cpu`. Transformer sẽ cộng các sample với các thuộc tính `user_id` và `resource_metadata` giống nhau, sau 60 giây kết quả sẽ được flush ra pipeline, thuộc tính của meter xuất ra sẽ bao gồm giá trị `user_id` của sample đầu tiên và `resource_metadata` của sample cuối cùng.

- `first`: lấy thuộc tính của sample đầu tiên làm thuọc tính của meter.
- `last`: lấy thuộc tính của sample cuối cùng làm thuọc tính của meter.
- `drop`: bỏ qua thuộc tính của sample.

### 2.3. Arithmetic
Transformer này cho phép tính toán nhiều sample và metadata để tạo ra một meter mới.
VD:
Tính toán tỉ lệ phần trăm sử dụng bộ nhớ RAM của máy ảo (memory_util). Transformer sẽ tính tỉ lệ giữa 2 sample `memory.usage` và `memory` theo công thức khai báo, giá trị nhận được được đánh đơn vị "%" và xếp vào loại "gauge"
```
sources:
	- name: memory_source
      interval: 60
      meters:
          - "memory.usage"
          - "memory"
      sinks:
          - memory_sink
sinks:
	- name: memory_sink
      transformers:
          - name: "arithmetic"
            parameters:
              target:
                name: "memory_util"
                unit: "%"
                type: "gauge"
                expr: "100 * $(memory.usage) / $(memory)"
      publishers:
          - notifier://
```


Tính toán thời gian sử dụng trung bình của từng CPU trong máy ảo (avg_cpu_per_core). Transformer sẽ tính tỉ lệ giữa sample `cpu` và `resource_metadata.cpu_number` của sample `cpu` (sử dụng lệnh ceilometer sample-show [cpu sample ID] để kiểm tra).
```
sources:
	- name: avg_cpu_source
      interval: 60
      meters:
          - "cpu"
      sinks:
          - avg_cpu_sink
sinks:
	- name: avg_cpu_sink
	  transformers:
    	  - name: "arithmetic"
      		parameters:
        	   target:
          	   	 name: "avg_cpu_per_core"
          		 unit: "ns"
          		 type: "cumulative"
          	 	 expr: "$(cpu) / ($(cpu).resource_metadata.cpu_number or 1)"
       publishers:
          - notifier://
```

### 2.4. Rate of change
Transformer này sẽ tính toán sự thay đổi giá trị giữa 2 datapoint của sample theo từng giây. Ta có thể dùng `scale` để tính toán giá trị gốc của sample  sang giá trị mới với đơn vị mới, sau đó transformer sẽ tính toán theo giá trị mới này.

VD:
Tính toán tỉ lệ phần trăm sử dụng CPUcủa máy ảo (cpu_util)
```
sources:
	- name: cpu_source
      interval: 60
      meters:
          - "cpu"
      sinks:
          - cpu_sink
sinks:
	- name: cpu_sink
	  transformers:
    	  - name: "rate_of_change"
     	    parameters:
          	   target:
              	 name: "cpu_util"
                 unit: "%"
              	 type: "gauge"
              	 scale: "100.0 / (10**9 * (resource_metadata.cpu_number or 1))"
      publishers:
         - notifier://        	 
```

### 2.5. Unit conversion
Transformer sử dụng để đặt đơn vị cho các meter. Ta có thể cấu hình giá trị `scale` để tính toán giá trị metric mới dựa trên sample. 
VD:
Xuất ra các meter về thông số đọc ghi của disk theo đơn vị KB.
```
sources:
	- name: disk_source
      interval: 60
      meters:
          - "disk.read.bytes"
          - "disk.write.bytes"
      sinks:
          - disk_sink
sinks:
	- name: disk_sink
	  transformers:
    	  - name: "unit_conversion"
      	    parameters:
          	   source:
                  map_from:
                  	name: "disk\\.(read|write)\\.bytes"
          	   target:
              	  map_to:
                  	name: "disk.\\1.kilobytes"
              	    scale: "volume * 1.0 / 1024.0"
              		unit: "KB"
      publishers:
         - notifier://   
```

### 2.6. Delta
Transformer này tính toán sự thay đổi giữa 2 sample datapoint của 1 resource.
VD:
Tính toán thời gian sử dụng CPU. Transformer sẽ trừ giá trị của 2 sample datapoint của `cpu`. `growth_only: True`: meter sẽ chỉ lấy giá trị khi delta nhận được là dương.

```
sources:
	- name: cpu_source
      interval: 60
      meters:
          - "cpu"
      sinks:
          - cpu_delta_sink
sinks:
	- name: cpu_delta_sink
	  transformers:
    	  - name: "delta"
      		parameters:
        		target:
            	name: "cpu.delta"
        		growth_only: True
      publishers:
         - notifier://   
```

Tham khảo:

[1]- http://aalvarez.me/blog/posts/understanding-ceilometer-transformers.html

[2]- https://docs.openstack.org/ceilometer/latest/admin/telemetry-data-pipelines.html#telemetry-transformers

