using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RadixSortTest : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        int[] array = { 53, 3, 542, 748, 14, 214 };
        //Debug.Log("Before Sort: " + string.Join(' ', array));
        //Sort(array);
        //Debug.Log("After Sort: " + string.Join(' ', array));

        array = new int[1000];
        for (int i = 0; i < array.Length; ++i)
            array[i] = (int)(Random.value * array.Length);
        Debug.Log("Before Sort: " + string.Join(' ', array));
        Sort(array);
        Debug.Log("After Sort: " + string.Join(' ', array));
    }

    void Sort(int[] arr)
    {
        // 1. �õ������е����λ��
        // �ҳ�������������
        int max = arr[0];
        for (int i = 1; i < arr.Length; i++)
        {
            if (arr[i] > max)
                max = arr[i];
        }

        // �õ�������ǵڼ�λ
        int maxLength = (max + "").Length;

        // 2. ��ʼ����
        // ����һ��2ά���飬��ʾ10��Ͱ��ÿ��Ͱ����һ��1ά����
        // ˵����
        // 1. 2ά�������10��1ά����
        // 2. Ϊ�˷�ֹ�ڷ����ʱ�����������ÿһ��1ά���ݣ���С��Ϊarr.length
        int[,] bucket = new int[10, arr.Length];

        // bucketElementCounts[0]������bucket[0]��Ͱ�������ݵĸ���
        int[] bucketElementCounts = new int[10];
        
        // �����ӵ�λ����λ��ÿ�β��� 10 * n
        for (int i = 0, n = 1; i < maxLength; i++, n *= 10)
        {
            // ���ÿ��Ԫ�صĶ�Ӧλ�������򣬵�һ��ѭ���Ǹ�λ���ڶ�����ʮλ������
            for (int j = 0; j < arr.Length; j++)
            {
                int digitOfElement = arr[j] / n % 10;
                bucket[digitOfElement, bucketElementCounts[digitOfElement]] = arr[j];
                bucketElementCounts[digitOfElement]++;
            }

            // ����ÿ��Ͱ��˳�򣬱���ÿ��Ͱ
            int index = 0;
            for (int k = 0; k < bucketElementCounts.Length; k++)
            {
                if (bucketElementCounts[k] != 0)
                {
                    for (int l = 0; l < bucketElementCounts[k]; l++)
                    {
                        arr[index++] = bucket[k, l];
                    }
                }
                bucketElementCounts[k] = 0;
            }

            // ����һ��λ��ѭ������
            //Debug.Log("Sort " + i + ": " + string.Join(' ', arr));
        }
    }

}
