# 🚀 Terraform AWS: VPC dengan NAT Instance, ALB, dan Private EC2 Web Servers

Proyek ini menggunakan **Terraform** untuk membangun infrastruktur AWS yang lengkap dan siap pakai, termasuk:

- 1 buah **VPC**
- 2 **public subnet** (masing-masing di AZ `a` dan `b`)
- 2 **private subnet** (masing-masing di AZ `a` dan `b`)
- 1 **NAT Instance** untuk akses internet dari subnet privat
- 2 buah **EC2 instance** di subnet privat (web server)
- 1 buah **Application Load Balancer (ALB)** yang berada di subnet publik untuk meneruskan trafik HTTP ke kedua instance privat
- **Output otomatis**: IP publik NAT Instance dan DNS dari Load Balancer agar bisa langsung diakses lewat browser
