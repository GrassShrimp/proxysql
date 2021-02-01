package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"sync"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

type statsMysqlQueryDigest struct {
	DigestText string `gorm:"column:digest_text" json:"digest_text"`
	CountStar  uint   `gorm:"column:count_star" json:"count_star"`
	SumTime    uint   `gorm:"column:sum_time" json:"sum_time"`
}

func (statsMysqlQueryDigest) TableName() string {
	return "stats_mysql_query_digest"
}

func main() {
	dsnList := []string{
		"cluster1:secret1pass@tcp(proxysql-0.proxysql.default.svc.cluster.local:6032)/admin?charset=utf8mb4&parseTime=True&loc=Local",
		"cluster1:secret1pass@tcp(proxysql-1.proxysql.default.svc.cluster.local:6032)/admin?charset=utf8mb4&parseTime=True&loc=Local",
		"cluster1:secret1pass@tcp(proxysql-2.proxysql.default.svc.cluster.local:6032)/admin?charset=utf8mb4&parseTime=True&loc=Local",
	}

	c := make(chan statsMysqlQueryDigest)

	wg := new(sync.WaitGroup)

	for _, dsn := range dsnList {
		wg.Add(1)
		go func(_c chan statsMysqlQueryDigest, _wg *sync.WaitGroup, _dsn string) {
			defer _wg.Done()
			db, err := gorm.Open(mysql.Open(_dsn), &gorm.Config{})

			if err != nil {
				panic(err)
			}

			queryDigestList := []statsMysqlQueryDigest{}

			result := db.Model(&statsMysqlQueryDigest{}).Where("schemaname != 'information_schema' AND digest_text NOT LIKE '%information_schema%' AND digest_text NOT LIKE '%?=?%'").Find(&queryDigestList)

			if result.Error != nil {
				panic(result.Error)
			}

			for _, queryDigest := range queryDigestList {
				_c <- queryDigest
			}
		}(c, wg, dsn)
	}

	go func(_c chan statsMysqlQueryDigest, _wg *sync.WaitGroup) {
		_wg.Wait()
		close(_c)
	}(c, wg)

	statistics := make(map[string]statsMysqlQueryDigest)

	for queryDigest := range c {
		sEnc := base64.StdEncoding.EncodeToString([]byte(queryDigest.DigestText))

		if _, ok := statistics[sEnc]; ok {
			statistics[sEnc] = statsMysqlQueryDigest{
				DigestText: queryDigest.DigestText,
				CountStar:  statistics[sEnc].CountStar + queryDigest.CountStar,
				SumTime:    statistics[sEnc].SumTime + queryDigest.SumTime,
			}
		} else {
			statistics[sEnc] = queryDigest
		}
	}

	result := []statsMysqlQueryDigest{}

	for _, queryDigest := range statistics {
		queryDigest.SumTime = queryDigest.SumTime / queryDigest.CountStar
		result = append(result, queryDigest)
	}

	output, _ := json.Marshal(result)
	fmt.Println(string(output))
}
